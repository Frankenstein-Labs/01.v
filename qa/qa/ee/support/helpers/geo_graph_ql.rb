# frozen_string_literal: true

module QA
  module EE
    module Support
      module Helpers
        module GeoGraphQl
          extend ActiveSupport::Concern

          included do
            before do
              @secondary_node_id = nil
            end
          end

          PROJECT_REPOSITORY_REGISTRIES_QUERY = <<~GRAPHQL
            query {
              geoNode {
                projectRepositoryRegistries(replicationState: SYNCED, sort: LAST_SYNCED_AT_DESC) {
                  nodes {
                    projectId
                    state
                  }
                }
              }
            }
          GRAPHQL

          LFS_OBJECT_REGISTRIES_QUERY = <<~GRAPHQL
            query {
              geoNode {
                lfsObjectRegistries(replicationState: SYNCED, sort: LAST_SYNCED_AT_DESC) {
                  nodes {
                    lfsObjectId
                    state
                  }
                }
              }
            }
          GRAPHQL

          JOB_ARTIFACT_REGISTRIES_QUERY = <<~GRAPHQL
            query {
              geoNode {
                jobArtifactRegistries(replicationState: SYNCED, sort: LAST_SYNCED_AT_DESC) {
                  nodes {
                    artifactId
                    state
                  }
                }
              }
            }
          GRAPHQL

          # Sends a GraphQL request to the secondary Geo node.
          #
          # Assumes there is only one secondary Geo node. Can be sent to any Geo
          # node, and that Geo node will route it to the Geo node with that ID.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @param query [String] GraphQL query string
          # @param variables [Hash] GraphQL variables (default: {})
          # @return [RestClient::Response] The API response
          # @raise [RuntimeError] if no secondary Geo node is found
          def geo_graphql_request(api_client, query, variables = {})
            secondary_node_id = fetch_secondary_node_id(api_client)
            raise "No secondary Geo node found" unless secondary_node_id

            url = QA::Runtime::API::Request.new(
              api_client,
              "/geo/node_proxy/#{secondary_node_id}/graphql"
            ).url

            payload = { query: query }
            payload[:variables] = variables unless variables.empty?

            QA::Support::API.post(
              url,
              payload.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
          end

          # Returns the secondary Geo node ID, fetching from API if not cached.
          #
          # Assumes there is only one secondary Geo node. Memoizes the result to avoid
          # repeated API calls within the same test.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @return [Integer, nil] The secondary node's database ID, or nil if not found
          def fetch_secondary_node_id(api_client)
            @secondary_node_id ||= fetch_secondary_node_id_from_api(api_client)
          end

          # Fetches the secondary Geo node ID from the API.
          #
          # Queries the /geo_nodes endpoint and finds the first node where primary is false.
          # Logs information about the found node or an error if none is found.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @return [Integer, nil] The secondary node's database ID, or nil if not found or on API error
          def fetch_secondary_node_id_from_api(api_client)
            url = QA::Runtime::API::Request.new(api_client, '/geo_nodes').url
            response = QA::Support::API.get(url)

            unless QA::Support::API.success?(response.code)
              QA::Runtime::Logger.error("Failed to fetch Geo nodes: #{response.code} - #{response.body}")
              return
            end

            nodes = QA::Support::API.parse_body(response)
            secondary = nodes.find { |node| node[:primary] == false }

            if secondary
              QA::Runtime::Logger.info("Found secondary Geo node: id=#{secondary[:id]}, name=#{secondary[:name]}")
              secondary[:id]
            else
              QA::Runtime::Logger.error("No secondary Geo node found in: #{nodes.pluck(:name)}")
              nil
            end
          end

          # Waits for a project repository to replicate to the secondary Geo site.
          #
          # Polls the secondary's GraphQL API via the primary's geo/node_proxy endpoint
          # until the project appears in the synced registries.
          #
          # registry_path is used to `dig` into the GraphQL registries query response
          # for the project ID.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @param project_id [Integer] The database ID of the project to wait for
          # @param max_duration [Integer, nil] Maximum seconds to wait (defaults to Geo.max_db_replication_time)
          # @return [Boolean] true if replication completed within timeout
          # @raise [QA::Support::Repeater::WaitExceededError] if timeout exceeded
          def wait_for_project_repository_replication(api_client, project_id:, max_duration: nil)
            max_duration ||= QA::EE::Runtime::Geo.max_db_replication_time

            wait_for_registry_replication(
              api_client: api_client,
              query: PROJECT_REPOSITORY_REGISTRIES_QUERY,
              registry_path: [:data, :geoNode, :projectRepositoryRegistries, :nodes],
              id_field: :projectId,
              expected_id: project_id,
              resource_name: "project repository",
              max_duration: max_duration
            )
          end

          # Waits for an LFS object to replicate to the secondary Geo site.
          #
          # Polls the secondary's GraphQL API via the primary's geo/node_proxy endpoint
          # until the LFS object appears in the synced registries.
          #
          # registry_path is used to `dig` into the GraphQL registries query response
          # for the LFS object ID.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @param lfs_object_id [Integer] The database ID of the LFS object to wait for
          # @param max_duration [Integer, nil] Maximum seconds to wait (defaults to Geo.max_file_replication_time)
          # @return [Boolean] true if replication completed within timeout
          # @raise [QA::Support::Repeater::WaitExceededError] if timeout exceeded
          def wait_for_lfs_object_replication(api_client, lfs_object_id:, max_duration: nil)
            max_duration ||= QA::EE::Runtime::Geo.max_file_replication_time

            wait_for_registry_replication(
              api_client: api_client,
              query: LFS_OBJECT_REGISTRIES_QUERY,
              registry_path: [:data, :geoNode, :lfsObjectRegistries, :nodes],
              id_field: :lfsObjectId,
              expected_id: lfs_object_id,
              resource_name: "LFS object",
              max_duration: max_duration
            )
          end

          # Waits for a job artifact to replicate to the secondary Geo site.
          #
          # Polls the secondary's GraphQL API via the primary's geo/node_proxy endpoint
          # until the job artifact appears in the synced registries.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @param job_artifact_id [Integer] The database ID of the job artifact to wait for
          # @param max_duration [Integer, nil] Maximum seconds to wait (defaults to Geo.max_file_replication_time)
          # @return [Boolean] true if replication completed within timeout
          # @raise [QA::Support::Repeater::WaitExceededError] if timeout exceeded
          def wait_for_job_artifact_replication(api_client, job_artifact_id:, max_duration: nil)
            max_duration ||= QA::EE::Runtime::Geo.max_file_replication_time

            wait_for_registry_replication(
              api_client: api_client,
              query: JOB_ARTIFACT_REGISTRIES_QUERY,
              registry_path: [:data, :geoNode, :jobArtifactRegistries, :nodes],
              id_field: :artifactId,
              expected_id: job_artifact_id,
              resource_name: "job artifact",
              max_duration: max_duration
            )
          end

          # Returns the last synced LFS object IDs on the secondary.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @return [Set<Integer>] Set of synced LFS object IDs
          # @raise [RuntimeError] if no secondary Geo node is found
          def synced_lfs_object_ids(api_client)
            response = geo_graphql_request(api_client, LFS_OBJECT_REGISTRIES_QUERY)

            unless QA::Support::API.success?(response.code)
              QA::Runtime::Logger.warn("Failed to fetch LFS registries: #{response.code}")
              return Set.new
            end

            body = QA::Support::API.parse_body(response)
            return Set.new if body[:errors]

            registries = body.dig(:data, :geoNode, :lfsObjectRegistries, :nodes) || []
            Set.new(registries.map { |r| r[:lfsObjectId].to_i })
          end

          # Returns the set of the last 100 LFS object IDs on the primary.
          #
          # Uses the admin data_management API to fetch all LFS objects.
          # This is useful for determining which LFS object was created after a push
          # by comparing sets before and after the operation.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @return [Set<Integer>] Set of LFS object IDs on the primary
          def primary_lfs_object_ids(api_client)
            url = QA::Runtime::API::Request.new(api_client, '/admin/data_management/lfs_objects').url
            response = QA::Support::API.get(url, per_page: '100')

            unless QA::Support::API.success?(response.code)
              QA::Runtime::Logger.warn("Failed to fetch LFS objects from primary: #{response.code}")
              return Set.new
            end

            objects = QA::Support::API.parse_body(response)
            Set.new(objects.map { |obj| obj[:record_identifier].to_i })
          end

          # Checks if all provided LFS object IDs are synced on the secondary.
          #
          # @param api_client [QA::Runtime::API::Client] API client with admin access
          # @param lfs_object_ids [Array<Integer>] LFS object IDs to check
          # @return [Boolean] true if all IDs are synced
          # @raise [RuntimeError] if no secondary Geo node is found
          def lfs_objects_synced?(api_client, lfs_object_ids)
            synced_ids = synced_lfs_object_ids(api_client)
            lfs_object_ids.all? { |id| synced_ids.include?(id) }
          end

          private

          def wait_for_registry_replication(
            api_client:, query:, registry_path:, id_field:, expected_id:, resource_name:, max_duration:
          )
            QA::Runtime::Logger.info("Waiting for #{resource_name} #{expected_id} to replicate via Geo GraphQL...")

            QA::Support::Retrier.retry_until(
              max_duration: max_duration,
              sleep_interval: 2,
              message: "Waiting for #{resource_name} #{expected_id} replication"
            ) do
              response = geo_graphql_request(api_client, query)

              unless QA::Support::API.success?(response.code)
                QA::Runtime::Logger.warn("Geo GraphQL request failed with code #{response.code}: #{response.body}")
                next false
              end

              body = QA::Support::API.parse_body(response)

              if body[:errors]
                QA::Runtime::Logger.warn("Geo GraphQL errors: #{body[:errors]}")
                next false
              end

              registries = body.dig(*registry_path) || []
              synced = registries.any? { |r| r[id_field].to_s == expected_id.to_s }

              if synced
                QA::Runtime::Logger.info("#{resource_name.capitalize} #{expected_id} successfully replicated (SYNCED)")
              else
                QA::Runtime::Logger.debug("#{resource_name.capitalize} #{expected_id} not yet in SYNCED registries. " \
                  "Found #{registries.size} synced registries.")
              end

              synced
            end
          end
        end
      end
    end
  end
end
