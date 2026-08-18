# frozen_string_literal: true

module QA
  module EE
    module Support
      module Helpers
        module SecretsManagement
          module SecretsManagerHelper
            # Deprovisions a secrets manager for a project or group via GraphQL
            #
            # @param resource [QA::Resource::Project, QA::Resource::Group] The resource to deprovision
            # @return [Hash] The GraphQL response
            def deprovision_secrets_manager(resource)
              if resource.is_a?(QA::Resource::Group)
                mutation = <<~GRAPHQL
                  mutation {
                    groupSecretsManagerDeprovision(input: { groupPath: "#{resource.full_path}" }) {
                      groupSecretsManager {
                        status
                      }
                      errors
                    }
                  }
                GRAPHQL
                mutation_key = :groupSecretsManagerDeprovision
              else
                mutation = <<~GRAPHQL
                  mutation {
                    projectSecretsManagerDeprovision(input: { projectPath: "#{resource.full_path}" }) {
                      projectSecretsManager {
                        status
                        project {
                          id
                          fullPath
                        }
                      }
                      errors
                    }
                  }
                GRAPHQL
                mutation_key = :projectSecretsManagerDeprovision
              end

              response = QA::Support::API.post(
                "#{QA::Runtime::Scenario.gitlab_address}/api/graphql",
                { query: mutation },
                headers: {
                  Authorization: "Bearer #{QA::Runtime::User::Store.default_api_client.personal_access_token}"
                }
              )

              parsed_response = JSON.parse(response.body, symbolize_names: true)
              mutation_response = parsed_response.dig(:data, mutation_key)

              QA::Runtime::Logger.info("Successfully initiated deprovisioning for: #{resource.full_path}")

              mutation_response
            end

            # Enrolls the GitLab instance in Secrets Manager via GraphQL.
            # Required on self-managed (GDK) since SM availability gates on
            # `Availability.enabled_for_*?` which checks (FF AND enrollment).
            #
            # Raises if enrollment fails for a reason other than "already enrolled"
            # so callers don't silently proceed with an unenrolled instance.
            #
            # @return [Hash] The GraphQL mutation response
            def enroll_instance_in_secrets_manager
              mutation = <<~GRAPHQL
                mutation {
                  instanceSecretsManagerEnroll(input: {}) {
                    errors
                  }
                }
              GRAPHQL

              response = QA::Support::API.post(
                "#{QA::Runtime::Scenario.gitlab_address}/api/graphql",
                { query: mutation },
                headers: {
                  Authorization: "Bearer #{QA::Runtime::User::Store.admin_api_client.personal_access_token}"
                }
              )

              parsed_response = JSON.parse(response.body, symbolize_names: true)
              # GraphQL surfaces auth/transport errors at the top level and
              # mutation-level errors inside the payload - check both.
              # rubocop:disable Rails/Pluck -- parsed_response[:errors] is a plain Ruby Array, not AR
              top_level_errors = (parsed_response[:errors] || []).map { |e| e[:message] }
              # rubocop:enable Rails/Pluck
              mutation_response = parsed_response.dig(:data, :instanceSecretsManagerEnroll)
              mutation_errors = mutation_response&.dig(:errors) || []
              errors = top_level_errors + mutation_errors

              unless errors.empty? || errors == ['Instance is already enrolled.']
                raise "Failed to enroll instance in Secrets Manager: #{errors.join(', ')}"
              end

              QA::Runtime::Logger.info("Instance is enrolled in Secrets Manager")
              mutation_response
            end
          end
        end
      end
    end
  end
end
