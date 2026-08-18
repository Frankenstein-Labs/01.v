# frozen_string_literal: true

module QA
  module EE
    module Flow
      module FoundationalFlow
        extend self
        include ::QA::Support::API

        # @param group [QA::Resource::Sandbox] a top-level group (root namespace)
        # @param flow_reference [String] e.g. 'developer/v1'
        # @param api_client [QA::Runtime::API::Client] owner/admin client
        def enable_on_group!(group, flow_reference:, api_client:)
          update_settings!(
            api_client,
            "/groups/#{group.id}",
            duo_features_enabled: true,
            enabled_foundational_flows: [flow_reference]
          )
        end

        # @param project [QA::Resource::Project]
        # @param api_client [QA::Runtime::API::Client] owner/admin client
        def enable_remote_flows_on_project!(project, api_client:)
          update_settings!(
            api_client,
            "/projects/#{project.id}",
            duo_features_enabled: true,
            duo_remote_flows_enabled: true
          )
        end

        DUO_ADD_ONS = %w[DUO_ENTERPRISE DUO_CORE].freeze

        # @param user [QA::Resource::User]
        # @param api_client [QA::Runtime::API::Client] admin client
        def assign_duo_seat!(user, api_client:)
          purchase = duo_add_on_purchase(api_client)
          raise "No active Duo add-on purchase (#{DUO_ADD_ONS.join('/')}) found to assign a seat" unless purchase

          mutation = <<~GQL
            mutation {
              userAddOnAssignmentCreate(input: {
                addOnPurchaseId: "#{purchase[:id]}",
                userId: "gid://gitlab/User/#{user.id}"
              }) { errors }
            }
          GQL

          errors = post_graphql(api_client, mutation).dig(:data, :userAddOnAssignmentCreate, :errors)
          raise "Failed to assign #{purchase[:name]} seat to #{user.username}: #{errors}" if errors.present?
        end

        # @param group [QA::Resource::Sandbox]
        # @param project [QA::Resource::Project]
        # @param flow_reference [String]
        # @param api_client [QA::Runtime::API::Client]
        def wait_for_flow_consumer!(group, project, flow_reference:, api_client:)
          ::QA::Support::Retrier.retry_until(
            max_duration: 600,
            sleep_interval: 10,
            message: "Wait for '#{flow_reference}' flow provisioning (consumer + active service account " \
              "+ project member) on #{project.full_path}"
          ) do
            state = flow_consumer_state(project, flow_reference: flow_reference, api_client: api_client)
            if flow_provisioning_ready?(state)
              ::QA::Runtime::Logger.info("Flow fully provisioned: #{state}")
              true
            else
              ::QA::Runtime::Logger.info("Flow not fully provisioned yet (#{state}); re-enabling flow.")
              enable_on_group!(group, flow_reference: flow_reference, api_client: api_client)
              false
            end
          end
        end

        private

        def flow_provisioning_ready?(state)
          consumer = state[:consumer]
          return false unless consumer&.dig(:id)

          service_account = consumer[:serviceAccount] || consumer.dig(:parentItemConsumer, :serviceAccount)
          return false unless service_account && service_account[:state] == 'active'

          (state[:service_account_project_members] || []).any? do |member|
            member[:username] == service_account[:username] &&
              member[:access_level].to_i >= ::QA::Resource::Members::AccessLevel::DEVELOPER
          end
        end

        def flow_consumer_state(project, flow_reference:, api_client:)
          item_gid = foundational_flow_item_gid(flow_reference, api_client)
          return { item_found: false } unless item_gid

          query = <<~GQL
            query {
              project(fullPath: "#{project.full_path}") {
                aiCatalogItemConsumerForItem(id: "#{item_gid}") {
                  id
                  serviceAccount { username state }
                  parentItemConsumer { serviceAccount { username state } }
                }
              }
            }
          GQL
          consumer = post_graphql(api_client, query).dig(:data, :project, :aiCatalogItemConsumerForItem)
          sa = consumer && (consumer.dig(:serviceAccount, :username) ||
            consumer.dig(:parentItemConsumer, :serviceAccount, :username))
          {
            item_found: true,
            consumer: consumer,
            service_account_project_members: sa ? project_members(project, sa, api_client) : nil
          }
        end

        def foundational_flow_item_gid(flow_reference, api_client)
          query = <<~GQL
            query {
              aiCatalogCustomAndFoundationalItems {
                nodes { ... on AiCatalogFlow { id foundationalFlowReference } }
              }
            }
          GQL
          nodes = post_graphql(api_client, query).dig(:data, :aiCatalogCustomAndFoundationalItems, :nodes) || []
          nodes.find { |node| node[:foundationalFlowReference] == flow_reference }&.dig(:id)
        end

        def project_members(project, username, api_client)
          request = ::QA::Runtime::API::Request.new(api_client, "/projects/#{project.id}/members/all", query: username)
          response = get(request.url)
          return [] unless response.code == ::QA::Support::API::HTTP_STATUS_OK

          parse_body(response).map { |m| { username: m[:username], access_level: m[:access_level] } }
        end

        def update_settings!(api_client, path, **body)
          request = ::QA::Runtime::API::Request.new(api_client, path)
          response = put(request.url, body)
          return if response.code == ::QA::Support::API::HTTP_STATUS_OK

          raise "Failed to update settings at #{path} (#{response.code}): #{response}"
        end

        def duo_add_on_purchase(api_client)
          purchases = post_graphql(api_client, 'query { addOnPurchases { id name } }')
            .dig(:data, :addOnPurchases) || []
          DUO_ADD_ONS.each do |name|
            match = purchases.find { |purchase| purchase[:name] == name }
            return match if match
          end
          nil
        end

        def post_graphql(api_client, query)
          request = ::QA::Runtime::API::Request.new(api_client, '/graphql')
          response = post(request.url, { query: query })
          unless response.code == ::QA::Support::API::HTTP_STATUS_OK
            raise "GraphQL request failed (#{response.code}): #{response}"
          end

          parse_body(response)
        end
      end
    end
  end
end
