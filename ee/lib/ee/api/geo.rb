# frozen_string_literal: true

require 'base64'

module EE
  module API
    module Geo
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          def sanitized_node_status_params
            # Exclude created_at and updated_at as these are managed by ActiveRecord
            # and may be nil if the sending node has an unsaved status object.
            valid_attributes = GeoNodeStatus.attribute_names - GeoNodeStatus::RESOURCE_STATUS_FIELDS - %w[id created_at updated_at]
            sanitized_params = params.slice(*valid_attributes)

            # sanitize status field
            sanitized_params['status'] = sanitized_params['status'].slice(*GeoNodeStatus::RESOURCE_STATUS_FIELDS) if sanitized_params['status']

            sanitized_params
          end

          # Check if a Geo request is legit or fail the flow
          #
          # @param [Hash] attributes to be matched against JWT
          def authorize_geo_transfer!(...)
            unauthorized! unless geo_jwt_decoder.valid_attributes?(...)
          end

          override :geo_proxy_response
          def geo_proxy_response
            # The methods used here (or their underlying methods) are cached
            # for:
            #
            # * 1 minute in memory
            # * 2 minutes in Redis
            #
            # The cached values are invalidated when changed.
            #
            non_proxy_response = super.merge({ geo_enabled: ::Gitlab::Geo.enabled? })

            return non_proxy_response unless ::Gitlab::Geo.secondary_with_primary?

            return non_proxy_response unless ::Gitlab::Geo.secondary_with_unified_url? ||
              ::Feature.enabled?(:geo_secondary_proxy_separate_urls, type: :ops)

            non_proxy_response.merge({
              geo_proxy_url: ::Gitlab::Geo.primary_node_internal_url,
              geo_proxy_extra_data: ::Gitlab::Geo.proxy_extra_data
            })
          end
        end

        resource :geo do
          desc 'Returns a replicable file from store (via CDN or sendfile)' do
            summary 'Internal endpoint that returns a replicable file'
            success code: 200
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[geo]
          end

          params do
            requires :replicable_name, type: String, desc: 'The replicable name of a replicator instance', documentation: { example: 'package_file' }
            requires :replicable_id, type: Integer, desc: 'The replicable ID of a replicable instance'
          end

          route_setting :authorization, skip_granular_token_authorization: :geo_jwt_auth
          get 'retrieve/:replicable_name/:replicable_id' do
            check_gitlab_geo_request_ip!
            params_sym = params.symbolize_keys
            authorize_geo_transfer!(**params_sym)

            decoded_params = geo_jwt_decoder.decode
            service = ::Geo::BlobUploadService.new(**params_sym, decoded_params: decoded_params)
            response = service.execute

            if response[:code] == :ok
              file = response[:file]
              present_carrierwave_file!(file)
            else
              error! response, response.delete(:code)
            end
          end

          desc 'Returns the list of pipeline refs for the project' do
            summary 'Used by secondary runners to verify the secondary instance has the very latest version'
            success code: 200, model: ::API::Entities::Geo::PipelineRefs
            is_array true
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[geo]
          end

          params do
            requires :gl_repository, type: String, desc: 'The repository to check'
          end

          route_setting :authorization, skip_granular_token_authorization: :geo_jwt_auth
          get 'repositories/:gl_repository/pipeline_refs' do
            check_gitlab_geo_request_ip!
            authenticate_by_gitlab_geo_node_token!

            _, project, _ = ::Gitlab::GlRepository.parse(params[:gl_repository])

            present pipeline_refs: project.repository.list_refs(['refs/pipelines/']).collect(&:name), with: ::API::Entities::Geo::PipelineRefs
          end

          # Post current node information to primary (e.g. health, repos synced, repos failed, etc.)
          #
          # Example request:
          #   POST /geo/status
          desc 'Posts the current node status to the primary site' do
            summary 'Internal endpoint that posts the current node status'
            success code: 200, model: ::API::Entities::GeoNodeStatus
            failure [
              { code: 400, message: '400 Bad Request' },
              { code: 401, message: '401 Unauthorized' }
            ]
            tags %w[geo]
          end

          params do
            optional :data, type: Hash, desc: 'Object that contains status information
              and replication metrics for the Geo node' do
              requires :geo_node_id, type: Integer, desc: 'Geo Node ID to look up its status'
              optional :db_replication_lag_seconds, type: Integer, desc: 'DB replication lag in seconds'
              optional :last_event_id, type: Integer, desc: 'Last event ID'
              optional :last_event_date, type: Time, desc: 'Last event date'
              optional :cursor_last_event_id, type: Integer, desc: 'Cursor last event ID'
              optional :cursor_last_event_date, type: Time, desc: 'Cursor last event date'
              optional :last_successful_status_check_at, type: Time, desc: 'Last successful status check date'
              optional :status_message, type: String, desc: 'Status message'
              optional :replication_slots_count, type: Integer, desc: 'Replication slots count'
              optional :replication_slots_used_count, type: Integer, desc: 'Replication slots used count'
              optional :replication_slots_max_retained_wal_bytes, type: Integer, desc: 'Maximum number of bytes retained in the WAL on the primary'
              optional :version, type: String, desc: 'Gitlab version'
              optional :revision, type: String, desc: 'Gitlab revision'
              optional :status, type: Hash, desc: 'Object that contains information on replication and verification
                status metrics for GitLab resources on Geo nodes' do
                # GeoNodeStatus::RESOURCE_STATUS_FIELDS
                optional :projects_count, type: Integer, desc: 'Projects count'
                optional :container_repositories_replication_enabled, type: Grape::API::Boolean, desc: 'Container repositories replication enabled'
                optional :lfs_objects_count, type: Integer, desc: 'LFS objects count'
                optional :lfs_objects_checksum_total_count, type: Integer, desc: 'LFS objects checksum total count'
                optional :lfs_objects_checksummed_count, type: Integer, desc: 'LFS objects checksummed count'
                optional :lfs_objects_checksum_failed_count, type: Integer, desc: 'LFS objects checksum failed count'
                optional :lfs_objects_synced_count, type: Integer, desc: 'LFS objects synced count'
                optional :lfs_objects_failed_count, type: Integer, desc: 'LFS objects failed count'
                optional :lfs_objects_registry_count, type: Integer, desc: 'LFS objects registry count'
                optional :lfs_objects_verification_total_count, type: Integer, desc: 'LFS objects verification total count'
                optional :lfs_objects_verified_count, type: Integer, desc: 'LFS objects verified count'
                optional :lfs_objects_verification_failed_count, type: Integer, desc: 'LFS objects verification failed count'
                optional :merge_request_diffs_count, type: Integer, desc: 'Merge request diffs count'
                optional :merge_request_diffs_checksum_total_count, type: Integer, desc: 'Merge request diffs checksum total count'
                optional :merge_request_diffs_checksummed_count, type: Integer, desc: 'Merge request diffs checksummed count'
                optional :merge_request_diffs_checksum_failed_count, type: Integer, desc: 'Merge request diffs checksum failed count'
                optional :merge_request_diffs_synced_count, type: Integer, desc: 'Merge request diffs synced count'
                optional :merge_request_diffs_failed_count, type: Integer, desc: 'Merge request diffs failed count'
                optional :merge_request_diffs_registry_count, type: Integer, desc: 'Merge request diffs registry count'
                optional :merge_request_diffs_verification_total_count, type: Integer, desc: 'Merge request diffs verification total count'
                optional :merge_request_diffs_verified_count, type: Integer, desc: 'Merge request diffs verified count'
                optional :merge_request_diffs_verification_failed_count, type: Integer, desc: 'Merge request diffs verified count'
                optional :package_files_count, type: Integer, desc: 'Packages files count'
                optional :package_files_checksum_total_count, type: Integer, desc: 'Packages files checksum total count'
                optional :package_files_checksummed_count, type: Integer, desc: 'Packages files checksummed count'
                optional :package_files_checksum_failed_count, type: Integer, desc: 'Packages files checksum failed count'
                optional :package_files_synced_count, type: Integer, desc: 'Packages files synced count'
                optional :package_files_failed_count, type: Integer, desc: 'Packages files failed count'
                optional :package_files_registry_count, type: Integer, desc: 'Packages files registry count'
                optional :package_files_verification_total_count, type: Integer, desc: 'Packages files verification total count'
                optional :package_files_verified_count, type: Integer, desc: 'Packages files verified count'
                optional :package_files_verification_failed_count, type: Integer, desc: 'Packages files verification failed count'
                optional :packages_nuget_symbols_count, type: Integer, desc: 'NuGet symbols count'
                optional :packages_nuget_symbols_checksum_total_count, type: Integer, desc: 'NuGet symbols checksum total count'
                optional :packages_nuget_symbols_checksummed_count, type: Integer, desc: 'NuGet symbols checksummed count'
                optional :packages_nuget_symbols_checksum_failed_count, type: Integer, desc: 'NuGet symbols checksum failed count'
                optional :packages_nuget_symbols_synced_count, type: Integer, desc: 'NuGet symbols synced count'
                optional :packages_nuget_symbols_failed_count, type: Integer, desc: 'NuGet symbols failed count'
                optional :packages_nuget_symbols_registry_count, type: Integer, desc: 'NuGet symbols registry count'
                optional :packages_nuget_symbols_verification_total_count, type: Integer, desc: 'NuGet symbols verification total count'
                optional :packages_nuget_symbols_verified_count, type: Integer, desc: 'NuGet symbols verified count'
                optional :packages_nuget_symbols_verification_failed_count, type: Integer, desc: 'NuGet symbols verification failed count'
                optional :terraform_state_versions_count, type: Integer, desc: 'Terraform state versions count'
                optional :terraform_state_versions_checksum_total_count, type: Integer, desc: 'Terraform state versions checksum total count'
                optional :terraform_state_versions_checksummed_count, type: Integer, desc: 'Terraform state versions checksummed count'
                optional :terraform_state_versions_checksum_failed_count, type: Integer, desc: 'Terraform state versions checksum failed count'
                optional :terraform_state_versions_synced_count, type: Integer, desc: 'Terraform state versions synced count'
                optional :terraform_state_versions_failed_count, type: Integer, desc: 'Terraform state versions failed count'
                optional :terraform_state_versions_registry_count, type: Integer, desc: 'Terraform state versions registry count'
                optional :terraform_state_versions_verification_total_count, type: Integer, desc: 'Terraform state versions verification total count'
                optional :terraform_state_versions_verified_count, type: Integer, desc: 'Terraform state versions verified count'
                optional :terraform_state_versions_verification_failed_count, type: Integer, desc: 'Terraform state versions verification failed count'
                optional :snippet_repositories_count, type: Integer, desc: 'Snippet repositories count'
                optional :snippet_repositories_checksum_total_count, type: Integer, desc: 'Snippet repositories checksum total count'
                optional :snippet_repositories_checksummed_count, type: Integer, desc: 'Snippet repositories checksummed count'
                optional :snippet_repositories_checksum_failed_count, type: Integer, desc: 'Snippet repositories checksum failed count'
                optional :snippet_repositories_synced_count, type: Integer, desc: 'Snippet repositories synced count'
                optional :snippet_repositories_failed_count, type: Integer, desc: 'Snippet repositories failed count'
                optional :snippet_repositories_registry_count, type: Integer, desc: 'Snippet repositories registry count'
                optional :snippet_repositories_verification_total_count, type: Integer, desc: 'Snippet repositories verification total count'
                optional :snippet_repositories_verified_count, type: Integer, desc: 'Snippet repositories verified count'
                optional :snippet_repositories_verification_failed_count, type: Integer, desc: 'Snippet repositories verification failed count'
                optional :group_wiki_repositories_count, type: Integer, desc: 'Group wiki repositories count'
                optional :group_wiki_repositories_checksum_total_count, type: Integer, desc: 'Group wiki repositories checksum total count'
                optional :group_wiki_repositories_checksummed_count, type: Integer, desc: 'Group wiki repositories checksummed count'
                optional :group_wiki_repositories_checksum_failed_count, type: Integer, desc: 'Group wiki repositories checksum failed count'
                optional :group_wiki_repositories_synced_count, type: Integer, desc: 'Group wiki repositories synced count'
                optional :group_wiki_repositories_failed_count, type: Integer, desc: 'Group wiki repositories failed count'
                optional :group_wiki_repositories_registry_count, type: Integer, desc: 'Group wiki repositories registry count'
                optional :group_wiki_repositories_verification_total_count, type: Integer, desc: 'Group wiki repositories verification total count'
                optional :group_wiki_repositories_verified_count, type: Integer, desc: 'Group wiki repositories verified count'
                optional :group_wiki_repositories_verification_failed_count, type: Integer, desc: 'Group wiki repositories verification failed count'
                optional :pipeline_artifacts_count, type: Integer, desc: 'Pipeline artifacts count'
                optional :pipeline_artifacts_checksum_total_count, type: Integer, desc: 'Pipeline artifacts checksum total count'
                optional :pipeline_artifacts_checksummed_count, type: Integer, desc: 'Pipeline artifacts checksummed count'
                optional :pipeline_artifacts_checksum_failed_count, type: Integer, desc: 'Pipeline artifacts checksum failed count'
                optional :pipeline_artifacts_synced_count, type: Integer, desc: 'Pipeline artifacts synced count'
                optional :pipeline_artifacts_failed_count, type: Integer, desc: 'Pipeline artifacts failed count'
                optional :pipeline_artifacts_registry_count, type: Integer, desc: 'Pipeline artifacts registry count'
                optional :pipeline_artifacts_verification_total_count, type: Integer, desc: 'Pipeline artifacts verification total count'
                optional :pipeline_artifacts_verified_count, type: Integer, desc: 'Pipeline artifacts verified count'
                optional :pipeline_artifacts_verification_failed_count, type: Integer, desc: 'Pipeline artifacts verification failed count'
                optional :pages_deployments_count, type: Integer, desc: 'Pages deployments count'
                optional :pages_deployments_checksum_total_count, type: Integer, desc: 'Pages deployments checksum total count'
                optional :pages_deployments_checksummed_count, type: Integer, desc: 'Pages deployments checksummed count'
                optional :pages_deployments_checksum_failed_count, type: Integer, desc: 'Pages deployments checksum failed count'
                optional :pages_deployments_synced_count, type: Integer, desc: 'Pages deployments synced count'
                optional :pages_deployments_failed_count, type: Integer, desc: 'Pages deployments failed count'
                optional :pages_deployments_registry_count, type: Integer, desc: 'Pages deployments registry count'
                optional :pages_deployments_verification_total_count, type: Integer, desc: 'Pages deployments verification total count'
                optional :pages_deployments_verified_count, type: Integer, desc: 'Pages deployments verified count'
                optional :pages_deployments_verification_failed_count, type: Integer, desc: 'Pages deployments verification failed count'
                optional :uploads_count, type: Integer, desc: 'Uploads count'
                optional :uploads_checksum_total_count, type: Integer, desc: 'Uploads checksum total count'
                optional :uploads_checksummed_count, type: Integer, desc: 'Uploads checksummed count'
                optional :uploads_checksum_failed_count, type: Integer, desc: 'Uploads checksum failed count'
                optional :uploads_synced_count, type: Integer, desc: 'Uploads synced count'
                optional :uploads_failed_count, type: Integer, desc: 'Uploads failed count'
                optional :uploads_registry_count, type: Integer, desc: 'Uploads registry count'
                optional :uploads_verification_total_count, type: Integer, desc: 'Uploads verification total count'
                optional :uploads_verified_count, type: Integer, desc: 'Uploads verified count'
                optional :uploads_verification_failed_count, type: Integer, desc: 'Uploads verification failed count'
                optional :job_artifacts_count, type: Integer, desc: 'Job artifacts count'
                optional :job_artifacts_checksum_total_count, type: Integer, desc: 'Job artifacts checksum total count'
                optional :job_artifacts_checksummed_count, type: Integer, desc: 'Job artifacts checksummed count'
                optional :job_artifacts_checksum_failed_count, type: Integer, desc: 'Job artifacts checksum failed count'
                optional :job_artifacts_synced_count, type: Integer, desc: 'Job artifacts synced count'
                optional :job_artifacts_failed_count, type: Integer, desc: 'Job artifacts failed count'
                optional :job_artifacts_registry_count, type: Integer, desc: 'Job artifacts registry count'
                optional :job_artifacts_verification_total_count, type: Integer, desc: 'Job artifacts verification total count'
                optional :job_artifacts_verified_count, type: Integer, desc: 'Job artifacts verified count'
                optional :job_artifacts_verification_failed_count, type: Integer, desc: 'Job artifacts verification failed count'
                optional :ci_secure_files_count, type: Integer, desc: 'CI secure files count'
                optional :ci_secure_files_checksum_total_count, type: Integer, desc: 'CI secure files checksum total count'
                optional :ci_secure_files_checksummed_count, type: Integer, desc: 'CI secure files checksummed count'
                optional :ci_secure_files_checksum_failed_count, type: Integer, desc: 'CI secure files checksum failed count'
                optional :ci_secure_files_synced_count, type: Integer, desc: 'CI secure files synced count'
                optional :ci_secure_files_failed_count, type: Integer, desc: 'CI secure files failed count'
                optional :ci_secure_files_registry_count, type: Integer, desc: 'CI secure files registry count'
                optional :ci_secure_files_verification_total_count, type: Integer, desc: 'CI secure files verification total count'
                optional :ci_secure_files_verified_count, type: Integer, desc: 'CI secure files verified count'
                optional :ci_secure_files_verification_failed_count, type: Integer, desc: 'CI secure files verification failed count'
                optional :container_repositories_count, type: Integer, desc: 'Container repositories count'
                optional :container_repositories_checksum_total_count, type: Integer, desc: 'Container repositories checksum total count'
                optional :container_repositories_checksummed_count, type: Integer, desc: 'Container repositories checksummed count'
                optional :container_repositories_checksum_failed_count, type: Integer, desc: 'Container repositories checksum failed count'
                optional :container_repositories_synced_count, type: Integer, desc: 'Container repositories synced count'
                optional :container_repositories_failed_count, type: Integer, desc: 'Container repositories failed count'
                optional :container_repositories_registry_count, type: Integer, desc: 'Container repositories registry count'
                optional :container_repositories_verification_total_count, type: Integer, desc: 'Container repositories verification total count'
                optional :container_repositories_verified_count, type: Integer, desc: 'Container repositories verified count'
                optional :container_repositories_verification_failed_count, type: Integer, desc: 'Container repositories verification failed count'
                optional :git_fetch_event_count_weekly, type: Integer, desc: 'Git fetch event count weekly'
                optional :git_push_event_count_weekly, type: Integer, desc: 'Git push event count weekly'
                optional :proxy_remote_requests_event_count_weekly, type: Integer, desc: 'Proxy remote requests event count weekly'
                optional :proxy_local_requests_event_count_weekly, type: Integer, desc: 'Proxy local requests event count weekly'
              end
            end
          end

          route_setting :authorization, skip_granular_token_authorization: :geo_jwt_auth
          post 'status' do
            check_gitlab_geo_request_ip!
            authenticate_by_gitlab_geo_node_token!

            db_status = GeoNode.find(params[:geo_node_id]).find_or_build_status

            unless db_status.update(sanitized_node_status_params.merge(last_successful_status_check_at: Time.now.utc))
              render_validation_error!(db_status)
            end
          end

          # Secondaries report resources that persistently fail verification so
          # the primary can act on them (for example, re-verify its own
          # checksum for a resource stuck in a checksum mismatch).
          #
          # The path and param shape are intentionally generic (not specific to
          # any one error type) since REST API v4 endpoints are expensive to
          # change once shipped: `error_type` discriminates what a given entry
          # means, and `context` carries error-type-specific extra data.
          desc 'Reports resources that persistently fail verification on a secondary' do
            summary 'Internal endpoint that reports persistent verification failures to the primary'
            success code: 202
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 404, message: '404 Not found' },
              { code: 400, message: '400 Bad request' }
            ]
            tags %w[geo]
          end

          params do
            requires :geo_node_id, type: Integer, desc: 'The Geo node ID of the reporting secondary'
            requires :failures, type: Array, desc: 'Persistent verification failures reported by the secondary' do
              requires :error_type, type: String, desc: 'The type of verification error being reported',
                documentation: { example: 'checksum_mismatch' }
              requires :replicable_name, type: String, desc: 'The replicable name of a replicator instance',
                documentation: { example: 'upload' }
              requires :replicable_id, type: Integer, desc: 'The model record ID'
              requires :verification_retry_count, type: Integer, desc: 'The number of consecutive verification failures'
              optional :context, type: Hash, desc: 'Additional error-type-specific data'
            end
          end

          route_setting :authorization, skip_granular_token_authorization: :geo_jwt_auth
          post 'failures' do
            check_gitlab_geo_request_ip!
            authenticate_by_gitlab_geo_node_token!

            not_found! unless ::Gitlab::Geo.primary?
            not_found! unless ::Feature.enabled?(:geo_self_heal_checksum_mismatch, :instance, type: :ops)
            bad_request!('Too many failures') if params[:failures].size > ::Geo::VerificationFailureReportWorker::MAX_FAILURES_PER_REQUEST

            ::Geo::VerificationFailureReportWorker.perform_async(params[:geo_node_id], params[:failures].map(&:to_h))

            status 202
          end

          # git over SSH secondary endpoints -> primary related proxying logic
          #
          resource 'proxy_git_ssh' do
            format :json

            # For git clone/pull

            desc 'Responsible for making HTTP GET /repo.git/info/refs?service=git-upload-pack
                  request from secondary gitlab-shell to primary' do
              summary 'Internal endpoint that returns info refs upload pack for clone or pull operations'
              success code: 200
              failure [{ code: 401, message: '401 Unauthorized' }]
              tags %w[geo]
            end

            params do
              requires :secret_token, type: String, desc: 'Secret token to authenticate by gitlab shell'
              requires :data, type: Hash, desc: 'Object that contains the payload data for the Geo operation' do
                requires :gl_id, type: String, desc: 'ID of the user performing the operation'
                requires :primary_repo, type: String, desc: 'Primary repository to clone or pull from'
              end
            end

            route_setting :authorization, skip_granular_token_authorization: :gitlab_shell_token_auth
            post 'info_refs_upload_pack' do
              authenticate_by_gitlab_shell_token!
              params.delete(:secret_token)

              response = ::Gitlab::Geo::GitSSHProxy.new(params['data']).info_refs_upload_pack

              status(response.code)
              response.body
            end

            desc 'Responsible for making HTTP POST /repo.git/git-upload-pack
                  request from secondary gitlab-shell to primary' do
              summary 'Internal endpoint that posts git-upload-pack for clone or pull operations'
              success code: 200
              failure [{ code: 401, message: '401 Unauthorized' }]
              tags %w[geo]
            end

            params do
              requires :secret_token, type: String, desc: 'Secret token used to authenticate requests from gitlab-shell
                to Geo proxy endpoints'
              requires :data, type: Hash, desc: 'Object that contains the payload data for the Geo operation' do
                requires :gl_id, type: String, desc: 'ID of the user performing the operation'
                requires :primary_repo, type: String, desc: 'Primary repository to clone or pull from'
              end
              requires :output, type: String, desc: 'Output from git-upload-pack'
            end

            route_setting :authorization, skip_granular_token_authorization: :gitlab_shell_token_auth
            post 'upload_pack' do
              authenticate_by_gitlab_shell_token!
              params.delete(:secret_token)

              response = ::Gitlab::Geo::GitSSHProxy.new(params['data']).upload_pack(params['output'])

              status(response.code)
              response.body
            end

            # For git push

            desc 'Responsible for making HTTP GET /repo.git/info/refs?service=git-receive-pack
                  request from secondary gitlab-shell to primary' do
              summary 'Internal endpoint that returns git-received-pack output for git push'
              success code: 200
              failure [{ code: 401, message: '401 Unauthorized' }]
              tags %w[geo]
            end

            params do
              requires :secret_token, type: String, desc: 'Secret token used to authenticate requests from gitlab-shell
                to Geo proxy endpoints'
              requires :data, type: Hash, desc: 'Object that contains the payload data for the Geo operation' do
                requires :gl_id, type: String, desc: 'ID of the user performing the operation'
                requires :primary_repo, type: String, desc: 'Primary repository to push to'
              end
            end

            route_setting :authorization, skip_granular_token_authorization: :gitlab_shell_token_auth
            post 'info_refs_receive_pack' do
              authenticate_by_gitlab_shell_token!
              params.delete(:secret_token)

              response = ::Gitlab::Geo::GitSSHProxy.new(params['data']).info_refs_receive_pack
              status(response.code)
              response.body
            end

            desc 'Responsible for making HTTP POST /repo.git/info/refs?service=git-receive-pack
                  request from secondary gitlab-shell to primary' do
              summary 'Internal endpoint that posts git-receive-pack for git push'
              success code: 200
              failure [{ code: 401, message: '401 Unauthorized' }]
              tags %w[geo]
            end

            params do
              requires :secret_token, type: String, desc: 'Secret token used to authenticate requests from gitlab-shell
                to Geo proxy endpoints'
              requires :data, type: Hash, desc: 'Object that contains the payload data for the Geo operation' do
                requires :gl_id, type: String, desc: 'ID of the user performing the operation'
                requires :primary_repo, type: String, desc: 'Primary repository to push to'
              end
              requires :output, type: String, desc: 'Output from git-receive-pack'
            end

            route_setting :authorization, skip_granular_token_authorization: :gitlab_shell_token_auth
            post 'receive_pack' do
              authenticate_by_gitlab_shell_token!
              params.delete(:secret_token)

              response = ::Gitlab::Geo::GitSSHProxy.new(params['data']).receive_pack(params['output'])
              status(response.code)
              response.body
            end
          end

          resource 'node_proxy' do
            before do
              authenticated_as_admin!
            end

            route_param :id, type: Integer, desc: 'The ID of the Geo node' do
              helpers do
                def geo_node
                  strong_memoize(:geo_node) { GeoNode.find(params[:id]) }
                end
              end

              desc 'Query the GraphQL endpoint of an existing Geo node' do
                summary 'Query the GraphQL endpoint of an existing Geo node'
                success code: 200
                failure [
                  { code: 404, message: '404 GeoNode Not Found' },
                  { code: 500, message: '500 Internal Server Error' }
                ]
                tags %w[geo]
              end

              # Example request:
              #   POST /geo/node_proxy/:id/graphql
              route_setting :authorization, permissions: :read_geo_node, boundary_type: :instance
              post 'graphql' do
                not_found!('GeoNode') unless geo_node

                response = ::Geo::GraphqlRequestService.new(geo_node, current_user).execute(env['api.request.input'])
                error!({ error: 'An error occurred while processing the GraphQL request to the Geo node' }, 500) unless response

                status 200
                response
              end
            end
          end
        end
      end
    end
  end
end
