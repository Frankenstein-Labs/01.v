# frozen_string_literal: true

module QA
  module EE
    module Resource
      module GroupBase
        include DoraMetrics
        include QA::Resource::Errors

        # Get group work item epics
        #
        # @return [Array<QA::EE::Resource::WorkItemEpic>]
        def work_item_epics
          response = process_api_response(
            api_post_to(
              '/graphql',
              <<~GQL
                query {
                  group(fullPath: "#{full_path}") {
                    id
                    name
                    workItems {
                      nodes {
                        id
                        iid
                        title
                        description
                        workItemType {
                          name
                        }
                      }
                    }
                  }
                }
              GQL
            )
          )
          nodes = response.dig(:work_items, :nodes)
          nodes.map do |node|
            WorkItemEpic.init do |resource|
              resource.api_client = api_client
              resource.group = self
              # `id` field format: "gid://gitlab/WorkItem/:id"
              resource.id = node[:id].rpartition('/')[2]
              resource.iid = node[:iid]
              resource.title = node[:title]
              resource.description = node[:description]
            end
          end
        end

        # Get group iterations
        #
        # @return [Array<QA::EE::Resource::GroupIteration>]
        def iterations
          parse_body(api_get_from(api_iterations_path)).map do |iteration|
            GroupIteration.init do |resource|
              resource.group = self
              resource.api_client = api_client
              resource.id = iteration[:id]
              resource.iid = iteration[:iid]
              resource.title = iteration[:title]
              resource.description = iteration[:description]
            end
          end
        end

        def api_iterations_path
          "#{api_get_path}/iterations"
        end

        def api_delete_path
          if self_deletion_scheduled?
            "#{super}?permanently_remove=true&full_path=#{CGI.escape(updated_full_path)}"
          else
            super
          end
        end

        # Check if the group has already been scheduled to be deleted
        #
        # @return [Boolean]
        def self_deletion_scheduled?
          reload_with_fallback![:marked_for_deletion_on].present?
        end

        # Get updated full_path after deletion scheduled
        #
        # @return [String]
        def updated_full_path
          reload_with_fallback![:full_path]
        end

        # Remove the group unless it's already scheduled for deletion.
        def remove_via_api!(force: false)
          if self_deletion_scheduled? && !force
            QA::Runtime::Logger.debug("#{self.class.name} #{identifier} is already scheduled to be removed.")

            return
          end

          super()
        end

        # Immediately removes a sandboxed group if it is scheduled for deletion.
        def immediate_remove_via_api!
          raise 'Cannot immediately delete top level groups' unless respond_to?(:sandbox)

          remove_via_api!
          remove_via_api!(force: true)
        end

        # Get all compliance frameworks in the group
        #
        # @return [Array<QA::EE::Resource::ComplianceFramework>]
        def compliance_frameworks
          response = process_api_response(
            api_post_to(
              '/graphql',
              <<~GQL
                query {
                  group(fullPath: "#{full_path}") {
                    complianceFrameworks {
                      nodes {
                        id
                        name
                        description
                        color
                        default
                        pipelineConfigurationFullPath
                      }
                    }
                  }
                }
              GQL
            )
          )
          response[:nodes].map do |node|
            QA::EE::Resource::ComplianceFramework.init do |framework|
              # `id` field format: "gid://gitlab/ComplianceManagement::Framework/:id"
              framework.id = node[:id].rpartition('/')[2]
              framework.group = self
              framework.name = node[:name]
              framework.description = node[:description]
              framework.color = node[:color]
              framework.default = !!node[:default]
              framework.pipeline_configuration_full_path = node[:pipelineConfigurationFullPath]
            end.reload!
          end
        end

        private

        def reload_with_fallback!
          reload!.api_response
        rescue ResourceNotFoundError => e
          raise e unless respond_to?(:id) && id

          parse_body(api_get_from("/groups/#{id}"))
        end
      end
    end
  end
end
