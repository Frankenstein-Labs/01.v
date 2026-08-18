# frozen_string_literal: true

module API
  module Internal
    class Orbit < ::API::Base
      include ::API::Concerns::AiWorkflowsAccess
      include APIGuard

      allow_access_with_scope :mcp_orbit
      allow_access_with_scope :mcp
      allow_access_with_scope :read_api
      allow_ai_workflows_access

      before do
        # Backend internal API for the indexer: gated on knowledge_graph_infra, not the user-facing module.
        not_found! unless Feature.enabled?(:knowledge_graph_infra, :instance)
      end

      API_HEADER = 'Gitlab-Orbit-Api-Request'
      CLIENT_IP_HEADER = 'X-Gitlab-Orbit-Client-Ip'
      REDACTION_SOURCE = 'workhorse_orbit'
      MAX_REVISIONS = 5000
      BLOB_BYTES_LIMIT = 1_048_576
      # The JWT authenticator enforces `expected_sub_prefix: 'gkg-indexer:'`, so
      # the Gitaly client_name is always this constant value.
      KNOWLEDGE_GRAPH_CLIENT_NAME = 'gkg-indexer'

      helpers do
        def extract_client_ip_address
          request.headers[CLIENT_IP_HEADER].presence
        end

        def valid_ip_address?(value)
          return false if value.blank?

          IPAddr.new(value).present?
        rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
          false
        end

        def log_redaction_without_client_ip!
          ::Gitlab::AuthLogger.build.warn(
            message: 'Orbit redaction request has no valid client IP; group IP restrictions cannot be enforced',
            Labkit::Fields::GL_USER_ID => current_user&.id,
            source: REDACTION_SOURCE
          )
        end

        def authenticate_knowledge_graph_request!
          token = request.headers[API_HEADER]

          decoded = token.present? &&
            ::Analytics::KnowledgeGraph::JwtAuth.decode_token(token, expected_sub_prefix: 'gkg-indexer:')

          render_api_error!('Knowledge Graph JWT authentication invalid', :unauthorized) unless decoded
        end

        def find_merge_request_diff_or_not_found!(project)
          diff_record = ::MergeRequestDiff.find_by(id: params[:diff_id], project_id: project.id) # rubocop:disable CodeReuse/ActiveRecord -- scoped lookup by composite key not suitable for a finder class
          not_found!('merge_request_diff') unless diff_record

          diff_record
        end

        def find_project_or_not_found!
          project = find_project(params[:project_id])
          not_found! unless project

          project
        end

        def validate_fast_forward!(repository, left_revision, right_revision)
          return if Gitlab::Git.blank_ref?(left_revision) || left_revision == repository.empty_tree_id
          return if repository.ancestor?(left_revision, right_revision)

          bad_request!("left_tree_revision is not an ancestor of right_tree_revision (force push detected)")
        end
      end

      namespace 'internal' do
        namespace 'orbit' do
          desc 'Batch authorization check for resources' do
            detail 'Checks whether a user is authorized to access a set of resources. ' \
              'Called by Workhorse during orbit query redaction.'
            tags 'orbit'
            hidden true
            success code: 200
          end
          params do
            requires :resources, type: Array, desc: 'Resources to check' do
              requires :resource_type, type: String, desc: 'Resource type (e.g. project, merge_request)'
              requires :resource_ids, type: Array[Integer], desc: 'Resource IDs'
              requires :ability, type: String, desc: 'Ability to check (e.g. read_project)'
            end
          end
          route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
          post :redaction, feature_category: :knowledge_graph, urgency: :low do
            status 200
            verify_workhorse_api!
            authenticate!

            resources_by_type = {}
            params[:resources].each do |r|
              type = r[:resource_type]
              bad_request!("duplicate resource_type '#{type}'") if resources_by_type.key?(type)

              resources_by_type[type] = { 'ids' => r[:resource_ids], 'ability' => r[:ability] }
            end

            total_resources = resources_by_type.sum { |_, v| v['ids'].size }

            client_ip = extract_client_ip_address
            client_ip = nil unless valid_ip_address?(client_ip)
            log_redaction_without_client_ip! if client_ip.nil?

            redaction_start = ::Gitlab::Metrics::System.monotonic_time
            results = ::Gitlab::IpAddressState.with(client_ip) do # rubocop: disable CodeReuse/ActiveRecord -- not ActiveRecord
              ::Authz::RedactionService.new(
                user: current_user,
                resources_by_type: resources_by_type,
                source: REDACTION_SOURCE
              ).execute
            end
            redaction_duration = ::Gitlab::Metrics::System.monotonic_time - redaction_start

            filtered = results.sum { |_, id_map| id_map.count { |_, allowed| !allowed } }

            metrics = ::Gitlab::Metrics::KnowledgeGraph::Request
            metrics.observe_redaction_duration(redaction_duration)
            metrics.observe_redaction_batch_size(total_resources)
            metrics.observe_redaction_filtered(filtered)

            authorizations = results.map do |resource_type, id_map|
              { resource_type: resource_type, authorized: id_map.transform_keys(&:to_s) }
            end

            { authorizations: authorizations }
          end

          namespace 'project' do
            before do
              verify_workhorse_api!
              authenticate_knowledge_graph_request!
            end

            route_param :project_id, type: String, desc: 'The ID or path of the project' do
              desc 'Get project info' do
                detail 'Returns the default branch for the given project'
                tags 'orbit'
                hidden true
                success code: 200
              end
              route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
              get '/info', feature_category: :knowledge_graph, urgency: :low do
                project = find_project_or_not_found!

                {
                  project_id: project.id,
                  default_branch: project.default_branch_or_main
                }
              end

              namespace 'repository' do
                desc 'Download repository archive' do
                  detail 'Returns a tar.gz archive of the project repository at the given ref'
                  tags 'orbit'
                  hidden true
                  success code: 200
                end
                params do
                  optional :ref, type: String,
                    desc: 'Git ref to archive (branch, tag, or SHA). Defaults to the default branch.'
                end
                route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                get '/archive', feature_category: :knowledge_graph, urgency: :low do
                  project = find_project_or_not_found!
                  ref = params[:ref] || project.default_branch_or_main

                  check_repository_archive_download!(project.repository)
                  audit_repository_archive_download(project.repository, client_name: KNOWLEDGE_GRAPH_CLIENT_NAME)

                  send_git_archive project.repository,
                    ref: ref,
                    format: 'tar.gz',
                    append_sha: false,
                    client_name: KNOWLEDGE_GRAPH_CLIENT_NAME
                rescue Gitlab::Workhorse::ArchiveNotFoundError, RuntimeError => e
                  not_found!(e.message)
                end

                desc 'List repository commits' do
                  detail 'Returns a paginated list of commits for the given ref'
                  tags 'orbit'
                  hidden true
                  success code: 200
                end
                params do
                  optional :ref, type: String, desc: 'Branch, tag, or SHA. Defaults to the default branch.'
                  optional :since, type: DateTime, desc: 'Only commits after or on this date (ISO 8601)'
                  optional :until, type: DateTime, desc: 'Only commits before or on this date (ISO 8601)'
                  optional :per_page, type: Integer, desc: 'Number of commits per page',
                    default: 20, except_values: [0]
                  optional :page_token, type: String, desc: 'SHA of the last commit from the previous page'
                end
                route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                get '/commits', feature_category: :knowledge_graph, urgency: :low do
                  project = find_project_or_not_found!

                  limit = [params[:per_page], Kaminari.config.max_per_page].min
                  ref = params[:ref].presence || project.default_branch_or_main

                  # Request one extra commit to detect a next page, since Gitaly
                  # always returns a cursor regardless of remaining results.
                  commit_collection = project.repository.list_commits(
                    ref: ref,
                    committed_after: params[:since],
                    committed_before: params[:until],
                    pagination_params: {
                      limit: limit + 1,
                      page_token: params[:page_token]
                    }
                  )

                  commits = commit_collection.commits

                  if commits.size > limit
                    commits = commits.first(limit)
                    header 'X-Next-Page-Token', commits.last.sha
                  end

                  present commits, with: Entities::Commit
                rescue Gitlab::Git::CommandTimedOut
                  raise
                rescue Gitlab::Git::CommandError => error
                  bad_request!(error.message)
                end

                desc 'Stream changed file paths between two tree revisions' do
                  detail 'Returns changed paths as newline-delimited JSON via Workhorse. ' \
                    'Proxies to the Gitaly FindChangedPaths RPC. ' \
                    'Returns 400 if left_tree_revision is not an ancestor of right_tree_revision (force push).'
                  tags 'orbit'
                  hidden true
                  success code: 200
                end
                params do
                  requires :left_tree_revision, type: String, desc: 'Base tree revision (commit SHA)'
                  requires :right_tree_revision, type: String, desc: 'Target tree revision (commit SHA)'
                end
                route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                get '/changed_paths', feature_category: :knowledge_graph, urgency: :low do
                  project = find_project_or_not_found!
                  repository = project.repository

                  validate_fast_forward!(repository, params[:left_tree_revision], params[:right_tree_revision])

                  requests = [
                    ::Gitaly::FindChangedPathsRequest::Request.new(
                      tree_request: ::Gitaly::FindChangedPathsRequest::Request::TreeRequest.new(
                        left_tree_revision: params[:left_tree_revision],
                        right_tree_revision: params[:right_tree_revision]
                      )
                    )
                  ]

                  header(*Gitlab::Workhorse.send_changed_paths(
                    repository,
                    requests,
                    client_name: KNOWLEDGE_GRAPH_CLIENT_NAME
                  ))
                  body ''
                end

                desc 'Stream blob contents for given revisions' do
                  detail 'Returns blobs as length-prefixed protobuf frames via Workhorse. ' \
                    'Proxies to the Gitaly ListBlobs RPC. ' \
                    'Blobs larger than bytes_limit are truncated.'
                  tags 'orbit'
                  hidden true
                  success code: 200
                end
                params do
                  requires :revisions, type: Array[String], allow_blank: false,
                    desc: 'Git revisions to list blobs for'
                  optional :bytes_limit, type: Integer, default: BLOB_BYTES_LIMIT,
                    values: 1..BLOB_BYTES_LIMIT,
                    desc: "Maximum blob size in bytes (1 to #{BLOB_BYTES_LIMIT})"
                end
                route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                post '/list_blobs', feature_category: :knowledge_graph, urgency: :low do
                  if params[:revisions].size > MAX_REVISIONS
                    bad_request!("revisions is limited to #{MAX_REVISIONS} entries")
                  end

                  project = find_project_or_not_found!
                  status 200

                  header(*Gitlab::Workhorse.send_list_blobs(
                    project.repository,
                    params[:revisions],
                    client_name: KNOWLEDGE_GRAPH_CLIENT_NAME,
                    bytes_limit: params[:bytes_limit]
                  ))
                  body ''
                end
              end

              namespace 'merge_requests' do
                route_param :merge_request_iid, type: Integer, desc: 'MR IID (project-scoped)' do
                  desc 'Return the raw diff of the latest version of a merge request' do
                    detail 'Returns the unified patch for the most recent MergeRequestDiff, ' \
                      'streamed as text/plain via Workhorse.'
                    tags 'orbit'
                    hidden true
                    success code: 200
                  end
                  route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                  get '/raw_diffs', feature_category: :knowledge_graph, urgency: :low do
                    project = find_project_or_not_found!
                    merge_request = project.merge_requests.find_by_iid!(params[:merge_request_iid])

                    diff_refs = merge_request.diff_refs
                    not_found!('merge_request has no diff refs') unless diff_refs

                    send_git_diff(project.repository, diff_refs)
                  end
                end
              end

              namespace 'merge_request_diffs' do
                route_param :diff_id, type: Integer, desc: 'MergeRequestDiff.id' do
                  desc 'Return per-file diffs for a MergeRequestDiff' do
                    detail 'Reads persisted MergeRequestDiffFile diffs which covers in-PG, ' \
                      'external object storage, and live Gitaly recompute.'
                    tags 'orbit'
                    hidden true
                    success code: 200
                  end
                  params do
                    optional :paths, type: Array[String],
                      desc: 'Filter to these (new_path or old_path) entries, max 100.'
                  end
                  route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                  get '/', feature_category: :knowledge_graph, urgency: :low do
                    project = find_project_or_not_found!
                    diff_record = find_merge_request_diff_or_not_found!(project)

                    paths = params[:paths]
                    bad_request!('paths limited to 100 entries') if paths.present? && paths.size > 100

                    diffs = diff_record.raw_diffs(paths: paths.presence).first(100)

                    status 200
                    {
                      id: diff_record.id,
                      head_commit_sha: diff_record.head_commit_sha,
                      base_commit_sha: diff_record.base_commit_sha,
                      start_commit_sha: diff_record.start_commit_sha,
                      diffs: Entities::Diff.represent(diffs, enable_unidiff: true)
                    }
                  end

                  desc 'Return the full unified patch for a MergeRequestDiff' do
                    detail 'Returns all persisted file diffs concatenated as a single text/plain unified patch.'
                    tags 'orbit'
                    hidden true
                    success code: 200
                  end
                  route_setting :authorization, skip_granular_token_authorization: :orbit_internal_auth
                  get '/raw_diffs', feature_category: :knowledge_graph, urgency: :low do
                    project = find_project_or_not_found!
                    diff_record = find_merge_request_diff_or_not_found!(project)

                    diff_refs = diff_record.diff_refs
                    not_found!('merge_request_diff has no diff refs') unless diff_refs

                    send_git_diff(project.repository, diff_refs)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
