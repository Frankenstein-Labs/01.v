# frozen_string_literal: true

module QA
  module EE
    module Resource
      class SecurityScanPolicyProject < QA::Resource::Base
        attributes :full_path

        def resource_web_url(resource)
          super
        rescue ResourceURLMissingError
          # this particular resource does not expose a web_url property
        end

        # Defining api_get_path because it is required to be overridden for an api resource class
        #
        # @return [String]
        def api_get_path
          "/graphql"
        end

        # Graphql mutation for vulnerability item creation
        #
        # @return [String]
        def api_post_body
          <<~GQL
            mutation{
              securityPolicyProjectCreate(input: { fullPath: "#{full_path}" }) {
                project {
                  id
                  fullPath
                  branch: repository {
                    rootRef
                  }
                }
                errors
              }
            }
          GQL
        end

        def process_api_response(parsed_response)
          project_response = extract_graphql_resource(parsed_response, 'project')

          super(project_response)
        end

        # GraphQl endpoint to create a vulnerability
        alias_method :api_post_path, :api_get_path
      end
    end
  end
end
