# frozen_string_literal: true

require_relative 'zoekt_process_manager'

module Search
  module Zoekt
    module TestHelpers
      def ensure_zoekt_node!
        # Start zoekt processes if they're not already running
        process_manager = ::Search::Zoekt::ZoektProcessManager.instance
        process_manager.start

        # Create or find node using the URLs from process manager
        ::Search::Zoekt::Node.find_or_create_by!(
          index_base_url: process_manager.index_base_url,
          search_base_url: process_manager.search_base_url
        ) do |node|
          node.uuid = SecureRandom.uuid
          node.last_seen_at = Time.zone.now
        end
      end
      module_function :ensure_zoekt_node!

      def zoekt_node
        @zoekt_node ||= ensure_zoekt_node!
      end
      module_function :zoekt_node

      def zoekt_ensure_namespace_indexed!(namespace)
        root_namespace = namespace.root_ancestor
        zoekt_enabled_namespace = ::Search::Zoekt::EnabledNamespace.find_or_create_by!(namespace: root_namespace)
        replica = Replica.for_enabled_namespace!(zoekt_enabled_namespace)
        replica.ready!

        index = ::Search::Zoekt::Index.find_or_create_by!(zoekt_enabled_namespace: zoekt_enabled_namespace,
          node: zoekt_node,
          namespace_id: root_namespace.id,
          replica: replica)

        index.update!(state: :ready)
      end

      # Since in the test setup it is complicated to achieve indexing via pulling tasks,
      # we are sending the HTTP post request to the indexer for indexing.
      # At the end if indexed files exists(success callback), we are moving task to done and zoekt_repository to ready
      def zoekt_ensure_project_indexed!(project) # rubocop:disable Metrics/AbcSize -- N/A
        zoekt_ensure_namespace_indexed!(project.namespace)
        ::Search::Zoekt::IndexingTaskService.new(project.id, :index_repo).execute
        repository_storage = project.repository_storage
        connection_info = Gitlab::GitalyClient.connection_data(repository_storage)
        repository_path = "#{project.repository.disk_path}.git"
        address = connection_info['address']
        if address.match?(%r{\Aunix:[^/.]})
          path = address.split('unix:').last
          address = "unix:#{Rails.root.join(path)}"
        end

        payload = {
          GitalyConnectionInfo: {
            Address: address,
            Token: connection_info['token'],
            Storage: repository_storage,
            Path: repository_path
          },
          Callback: { name: 'index' },
          RepoID: project.id,
          ProjectFullPath: project.path_with_namespace,
          FileSizeLimit: Gitlab::CurrentSettings.elasticsearch_indexed_file_size_limit_kb.kilobytes,
          Timeout: '10s',
          Force: true,
          Metadata: {
            project_id: project.id,
            traversal_ids: project.namespace_ancestry,
            visibility_level: project.visibility_level,
            repository_access_level: project.repository_access_level,
            forked: project.forked? ? 't' : 'f',
            archived: project.archived? ? 't' : 'f'
          }.transform_values(&:to_s)
        }
        defaults = {
          headers: {
            'Content-Type' => 'application/json',
            'Gitlab-Zoekt-Api-Request' => ::Search::Zoekt::JwtAuth.authorization_header
          },
          body: payload.to_json,
          allow_local_requests: true,
          timeout: 10.seconds.to_i
        }
        node = zoekt_node
        url = ::Gitlab::Search::Zoekt::Client.new.send(:join_url, node.index_base_url, '/indexer/index')
        ::Gitlab::HTTP.post(url, defaults)
        # Add delay to allow Zoekt webserver to finish the indexing
        all_files_count = project.repository.ls_files('HEAD').count

        indexing_succeeded = false

        params = {
          headers: {
            'Content-Type' => 'application/json',
            ::Gitlab::Search::Zoekt::Client::JWT_HEADER => JwtAuth.authorization_header
          },
          body: {
            version: 2,
            forward_to: [
              query: {
                and: {
                  children: [
                    {
                      query_string: {
                        query: '.*'
                      }
                    },
                    {
                      meta: {
                        key: 'project_id', value: "^#{project.id}$"
                      }
                    }
                  ]
                }
              },
              endpoint: node.search_base_url
            ]
          }.to_json,
          allow_local_requests: true
        }
        search_url = ::Gitlab::Search::Zoekt::Client.new.send(
          :join_url, node.search_base_url, ::Gitlab::Search::Zoekt::Client::PROXY_SEARCH_PATH
        )
        1000.times do
          response = ::Gitlab::HTTP.post(search_url, params)
          raise response.body unless response.success?

          if response['Result'].try(:[], 'FileCount') == all_files_count
            Task.index_repo.where(project_identifier: project.id).update_all(state: :done)
            project.zoekt_repositories.update_all(state: :ready)
            indexing_succeeded = true
            break
          end

          sleep 0.1
        end

        raise "Zoekt indexing timed out for project #{project.id}." unless indexing_succeeded
      end
    end
  end

  RSpec.configure do |config|
    config.before do
      # The Default threshold is 30 seconds; This is to ensure nodes are always online in tests.
      stub_const('Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD', 1.day)
    end

    config.before(:each, :zoekt_settings_enabled) do
      stub_licensed_features(zoekt_code_search: true)
      stub_ee_application_setting(zoekt_indexing_enabled: true, zoekt_search_enabled: true)
      allow(::Search::Zoekt).to receive(:feature_available?).and_return(true)
    end

    config.before(:each, :zoekt_cache_disabled) do
      stub_ee_application_setting(zoekt_cache_response: false)
    end

    # Make sure we clean up Zoekt processes after all tests are done
    config.after(:suite) do
      if defined?(Search::Zoekt::ZoektProcessManager)
        zoekt_manager = Search::Zoekt::ZoektProcessManager.instance
        zoekt_manager.stop if zoekt_manager
      end
    end

    config.include Search::Zoekt::TestHelpers
  end
end
