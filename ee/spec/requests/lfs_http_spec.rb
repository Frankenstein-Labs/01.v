# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Git LFS API and storage', feature_category: :source_code_management do
  include LfsHttpHelpers
  include WorkhorseHelpers
  include WorkhorseLfsHelpers
  include EE::GeoHelpers
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  let(:user) { create(:user) }
  let!(:lfs_object) { create(:lfs_object, :with_file) }

  let(:headers) do
    {
      'Authorization' => authorization,
      'X-Sendfile-Type' => sendfile
    }.compact
  end

  let(:authorization) { nil }
  let(:sendfile) { nil }

  let(:sample_oid) { lfs_object.oid }
  let(:sample_size) { lfs_object.size }

  context 'with group wikis' do
    let_it_be(:group) { create(:group) }

    # LFS is not supported on group wikis, so we override the shared examples
    # to expect 404 responses instead.
    [
      'LFS http 200 response',
      'LFS http 200 blob response',
      'LFS http 403 response'
    ].each do |examples|
      shared_examples_for(examples) { it_behaves_like 'LFS http 404 response' }
    end

    it_behaves_like 'LFS http requests' do
      let(:container) { create(:group_wiki, :empty_repo, group: group) }
      let(:authorize_guest) { group.add_guest(user) }
      let(:authorize_download) { group.add_reporter(user) }
      let(:authorize_upload) { group.add_developer(user) }
    end
  end

  describe 'when handling lfs batch request' do
    subject(:batch_request) { post_lfs_json "#{project.http_url_to_repo}/info/lfs/objects/batch", body, headers }

    before do
      enable_lfs
    end

    describe 'download' do
      let(:project) { create(:project, :repository) }
      let(:lfs_object) { create(:lfs_object, :with_file) }
      let(:sample_oid) { lfs_object.oid }
      let(:sample_size) { lfs_object.size }

      before do
        project.add_maintainer(user)
        create(:lfs_objects_project, project: project, lfs_object: lfs_object)
      end

      it 'returns a valid JSON response with download actions and proper header structure', :aggregate_failures do
        post_lfs_json "#{project.http_url_to_repo}/info/lfs/objects/batch",
          {
            operation: 'download',
            objects: [{ oid: sample_oid, size: sample_size }]
          },
          { 'Authorization' => authorize_user }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match(
          a_hash_including(
            'objects' => [
              a_hash_including(
                'oid' => sample_oid,
                'size' => sample_size,
                'actions' => a_hash_including(
                  'download' => a_hash_including(
                    'href' => a_string_including("/gitlab-lfs/objects/#{sample_oid}"),
                    'header' => a_hash_including('Authorization')
                  )
                )
              )
            ]
          )
        )
      end

      it 'preserves from_secondary path in download URLs', :aggregate_failures do
        allow(::Gitlab::Geo).to receive(:secondary_node?).and_return(true)

        post_lfs_json batch_redirect_url(project),
          {
            operation: 'download',
            objects: [{ oid: sample_oid, size: sample_size }]
          },
          { 'Authorization' => authorize_user }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match(
          a_hash_including(
            'objects' => [
              a_hash_including(
                'actions' => a_hash_including(
                  'download' => a_hash_including(
                    'href' => a_string_including("/-/from_secondary")
                  )
                )
              )
            ]
          )
        )
      end

      it 'falls back to regular download when geo_referrer_secondary_node_id returns nil', :aggregate_failures do
        allow(::Gitlab::Geo).to receive(:secondary_node?).and_return(false)

        allow(::Gitlab::Geo::Logger).to receive(:warn)

        post_lfs_json batch_redirect_url(project),
          {
            operation: 'download',
            objects: [{ oid: sample_oid, size: sample_size }]
          },
          { 'Authorization' => authorize_user }

        expect(response).to have_gitlab_http_status(:ok)

        expect(::Gitlab::Geo::Logger).to have_received(:warn)

        download_href = json_response['objects'][0]['actions']['download']['href']
        expect(download_href).not_to include('from_secondary')
        expect(download_href).to include("/gitlab-lfs/objects/#{sample_oid}")
      end

      it 'validates geo_node_id against actual secondary nodes', :aggregate_failures, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/5336' do
        # Create a node with the specific ID that the route expects
        valid_secondary_node = create(:geo_node, :secondary, id: 2)
        another_secondary_node = create(:geo_node, :secondary)

        # Mock the basic Geo calls but use real secondary nodes
        allow(::Gitlab::Geo).to receive_message_chain(:secondary_nodes, :any?).and_return(true)
        allow(::Gitlab::Geo).to receive(:secondary_nodes).and_return([valid_secondary_node, another_secondary_node])
        allow(::Gitlab::Geo::Logger).to receive(:warn)

        # Use the existing helper that works
        post_lfs_json batch_redirect_url(project),
          {
            operation: 'download',
            objects: [{ oid: sample_oid, size: sample_size }]
          },
          { 'Authorization' => authorize_user }

        expect(response).to have_gitlab_http_status(:ok)
        expect(::Gitlab::Geo::Logger).not_to have_received(:warn)

        download_href = json_response['objects'][0]['actions']['download']['href']
        expect(download_href).to include('from_secondary')
        expect(download_href).to include('2')
      end
    end

    describe 'upload' do
      let(:project) { create(:project, :public) }
      let(:namespace) { project.namespace }
      let(:size_checker) { Namespaces::Storage::RootSize.new(namespace) }
      let(:body) do
        {
          'operation' => 'upload',
          'objects' => [
            { 'oid' => sample_oid,
              'size' => sample_size }
          ]
        }
      end

      shared_examples 'pushes new LFS objects' do
        let(:sample_size) { 150.megabytes }
        let(:sample_oid) { '91eff75a492a3ed0dfcb544d7f31326bc4014c8551849c192fd1e48d4dd2c897' }

        context 'and project is above the repository size limit' do
          before do
            allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
              allow(checker).to receive_messages(
                enabled?: true,
                current_size: 110.megabytes,
                limit: 100.megabytes
              )
            end
          end

          it 'responds with status 406' do
            batch_request

            expect(response).to have_gitlab_http_status(:not_acceptable)
            expect(json_response['message']).to eql('Your push to this repository cannot be completed because this repository has exceeded the allocated storage for your project. Contact your GitLab administrator for more information.')
          end
        end

        context 'and project will go over the repository size limit' do
          before do
            allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
              allow(checker).to receive_messages(
                enabled?: true,
                current_size: 200.megabytes,
                limit: 300.megabytes
              )
            end
          end

          it 'responds with status 406' do
            batch_request

            expect(response).to have_gitlab_http_status(:not_acceptable)
            expect(json_response['documentation_url']).to include('/help')
            expect(json_response['message']).to eql('Your push to this repository cannot be completed as it would exceed the allocated storage for your project. Contact your GitLab administrator for more information.')
          end
        end

        context 'when the namespace storage limit is exceeded', :saas do
          before do
            # Use create_or_replace_subscription because project.add_developer/add_maintainer
            # triggers Internal Events tracking, which auto-generates a FREE subscription
            create_or_replace_subscription(namespace, :ultimate)
            create(:namespace_root_storage_statistics, namespace: namespace)
            enforce_namespace_storage_limit(namespace)
            set_enforcement_limit(namespace, megabytes: 100)
            set_used_storage(namespace, megabytes: 140)
          end

          it 'responds with status 406' do
            batch_request

            expect(response).to have_gitlab_http_status(:not_acceptable)
            expect(json_response['message']).to eql(size_checker.error_message.push_error)
          end
        end

        context 'when the push size would exceed the namespace storage limit', :saas do
          before do
            # Use create_or_replace_subscription because project.add_developer/add_maintainer
            # triggers Internal Events tracking, which auto-generates a FREE subscription
            create_or_replace_subscription(namespace, :ultimate)
            create(:namespace_root_storage_statistics, namespace: namespace)
            enforce_namespace_storage_limit(namespace)
            set_enforcement_limit(namespace, megabytes: 200)
            set_used_storage(namespace, megabytes: 100)
          end

          it 'responds with status 406' do
            batch_request

            expect(response).to have_gitlab_http_status(:not_acceptable)
            expect(json_response['message']).to eql(size_checker.error_message.new_changes_error)
          end
        end
      end

      describe 'when request is authenticated' do
        context 'when user has project push access' do
          let(:authorization) { authorize_user }

          before do
            project.add_developer(user)
          end

          context 'when pushing a lfs object that does not exist' do
            it_behaves_like 'pushes new LFS objects'

            context 'when the namespace is over the free user cap limit', :saas do
              let(:namespace) { create(:group_with_plan, :private, :with_root_storage_statistics, plan: :free_plan) }

              before do
                project.update!(namespace: namespace)
                stub_ee_application_setting(dashboard_limit_enabled: true)
                enforce_namespace_storage_limit(namespace)
                set_enforcement_limit(namespace, megabytes: 100)
                set_used_storage(namespace, megabytes: 90)
                allow_next_instance_of(::Repositories::LfsApiController) do |instance|
                  allow(instance).to receive(:lfs_upload_access?).and_return(false)
                end
              end

              it 'responds with status 406', :aggregate_failures do
                batch_request

                expect(response).to have_gitlab_http_status(:not_acceptable)
                expect(json_response['documentation_url']).to include('/help', 'free_user_limit')
                expect(json_response['message']).to match(/Your top-level group is over the user limit/)
              end
            end
          end

          context 'when push includes an lfs object that already exists' do
            let(:existing_object) { create(:lfs_object, :with_file, size: 150.megabytes) }

            let(:body) do
              {
                'operation' => 'upload',
                'objects' => [
                  {
                    'oid' => sample_oid,
                    'size' => sample_size
                  },
                  {
                    'oid' => existing_object.oid,
                    'size' => existing_object.size
                  }
                ]
              }
            end

            before do
              create(
                :lfs_objects_project,
                project: project,
                lfs_object: existing_object
              )
            end

            it 'uses new objects for change size' do
              expect_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
                expect(checker).to receive(:changes_will_exceed_size_limit?).with(sample_size, project)
              end

              batch_request
            end

            context 'when the push will not go over the repository size limit' do
              let(:sample_size) { 75.megabytes }

              before do
                allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
                  allow(checker).to receive_messages(
                    enabled?: true,
                    current_size: 150.megabytes,
                    limit: 300.megabytes
                  )
                end
              end

              it 'responds with status 200' do
                batch_request

                expect(response).to have_gitlab_http_status(:ok)
              end
            end

            context 'when the push will go over the repository size limit' do
              let(:sample_size) { 275.megabytes }

              before do
                allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
                  allow(checker).to receive_messages(
                    enabled?: true,
                    current_size: 150.megabytes,
                    limit: 300.megabytes
                  )
                end
              end

              it 'responds with status 406' do
                batch_request

                expect(response).to have_gitlab_http_status(:not_acceptable)
              end
            end
          end

          context 'when pushing to a subgroup project' do
            let(:sample_size) { 150.megabytes }
            let(:sample_oid) { '91eff75a492a3ed0dfcb544d7f31326bc4014c8551849c192fd1e48d4dd2c897' }
            let(:group) { create(:group) }
            let(:subgroup) { create(:group, parent: group) }
            let(:project) { create(:project, group: subgroup) }

            context 'when the namespace storage limit is exceeded', :saas do
              before do
                # Use create_or_replace_subscription because project.add_developer/add_maintainer
                # triggers Internal Events tracking, which auto-generates a FREE subscription
                create_or_replace_subscription(group, :ultimate)
                create(:namespace_root_storage_statistics, namespace: group)
                enforce_namespace_storage_limit(group)
                set_enforcement_limit(group, megabytes: 70)
                set_used_storage(group, megabytes: 80)
              end

              it 'responds with status 406' do
                batch_request

                expect(response).to have_gitlab_http_status(:not_acceptable)
                expect(json_response['message']).to eql(size_checker.error_message.push_error)
              end
            end
          end

          context 'when Geo is not enabled' do
            context 'when custom_http_clone_url_root is not configured' do
              it 'returns hrefs based on external_url' do
                batch_request

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['objects'].first['actions']['upload']['href']).to start_with(Gitlab::Routing.url_helpers.root_url)
              end
            end

            context 'when custom_http_clone_url_root is configured' do
              before do
                stub_application_setting(custom_http_clone_url_root: 'http://customized')
              end

              it 'returns hrefs based on custom_http_clone_url_root' do
                batch_request

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['objects'].first['actions']['upload']['href']).to start_with('http://customized')
              end
            end
          end

          context 'when this site is a Geo primary site' do
            let(:primary) { create(:geo_node, :primary) }

            before do
              stub_current_geo_node(primary)
            end

            context 'when custom_http_clone_url_root is not configured' do
              it 'returns hrefs based on the Geo primary site URL' do
                batch_request

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['objects'].first['actions']['upload']['href']).to start_with(primary.url)
              end
            end

            context 'when custom_http_clone_url_root is configured' do
              before do
                stub_application_setting(custom_http_clone_url_root: 'http://customized')
              end

              it 'returns hrefs based on the Geo primary site URL' do
                batch_request

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['objects'].first['actions']['upload']['href']).to start_with(primary.url)
              end
            end
          end
        end

        context 'when deploy key has project push access' do
          let(:key) { create(:deploy_key) }
          let(:authorization) { authorize_deploy_key }

          before do
            project.deploy_keys_projects.create!(deploy_key: key, can_push: true)
          end

          it_behaves_like 'pushes new LFS objects'
        end
      end
    end
  end

  describe 'when pushing an lfs object' do
    before do
      enable_lfs
    end

    describe 'to one project' do
      let(:project) { create(:project) }
      let(:namespace) { project.namespace }

      context 'when user is authenticated' do
        let(:authorization) { authorize_user }
        let(:include_workhorse_jwt_header) { true }

        context 'when user has push access to the project' do
          before do
            project.add_developer(user)
          end

          context 'when project has repository size limit enabled' do
            before do
              allow_next_instance_of(Gitlab::RepositorySizeChecker) do |checker|
                allow(checker).to receive_messages(limit: 200, enabled?: true)
              end
            end

            it 'responds with status 200 when the push will stay under the limit' do
              put_finalize

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          context 'when namespace storage limits are enabled', :saas do
            before do
              # Use create_or_replace_subscription because project.add_developer/add_maintainer
              # triggers Internal Events tracking, which auto-generates a FREE subscription
              create_or_replace_subscription(namespace, :ultimate)
              create(:namespace_root_storage_statistics, namespace: namespace)
              enforce_namespace_storage_limit(namespace)
              set_enforcement_limit(namespace, megabytes: 50)
              set_used_storage(namespace, megabytes: 8)
            end

            it 'responds with status 200 when the push is under the limit' do
              put_finalize

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end
    end
  end

  def batch_redirect_url(project)
    uri = URI.parse(project.http_url_to_repo)
    File.join(uri.origin, '-/from_secondary/2', uri.path, "info/lfs/objects/batch")
  end

  def enable_lfs
    allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
  end

  def authorize_user
    ActionController::HttpAuthentication::Basic.encode_credentials(user.username, user.password)
  end

  def authorize_deploy_key
    ActionController::HttpAuthentication::Basic.encode_credentials("lfs+deploy-key-#{key.id}", Gitlab::LfsToken.new(key, project).token)
  end

  def post_lfs_json(url, body = nil, headers = nil)
    params = body.try(:to_json)
    headers = (headers || {}).merge('Content-Type' => LfsRequest::CONTENT_TYPE)

    post(url, params: params, headers: headers)
  end
end
