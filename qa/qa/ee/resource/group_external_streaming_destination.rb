# frozen_string_literal: true

module QA
  module EE
    module Resource
      class GroupExternalStreamingDestination < QA::Resource::Base
        include QA::Resource::GraphQL

        attributes :id,
          :name,
          :category,
          :config,
          :secret_token,
          :active

        attribute :group do
          QA::Resource::Group.fabricate_via_api! do |group|
            group.path = "audit-event-streaming-#{Faker::Alphanumeric.alphanumeric(number: 8)}"
          end
        end

        # Find a destination by name
        #
        # @param [QA::Resource::Group] group the group to query destinations for
        # @param [String] name the name of the destination to find
        # @return [GroupExternalStreamingDestination, nil] the destination or nil if not found
        def self.find_by_name(group:, name:)
          instance = new
          instance.group = group

          destinations = instance.all(group: group)
          destination_data = destinations.find { |d| d[:name] == name }

          return unless destination_data

          new.tap do |resource|
            resource.id = destination_data[:id].split('/').last
            resource.name = destination_data[:name]
            resource.secret_token = destination_data[:secret_token]
            resource.config = if destination_data[:config].is_a?(String)
                                JSON.parse(destination_data[:config])
                              else
                                destination_data[:config]
                              end

            resource.category = destination_data[:category]
            resource.active = destination_data[:active]
            resource.group = group
            resource.api_response = destination_data
          end
        end

        def initialize
          @category = 'http'
          @active = true
          @config = {}
        end

        def resource_web_url(resource)
          super
        rescue ResourceURLMissingError
          # this particular resource does not expose a web_url property
        end

        def gid
          "gid://gitlab/AuditEvents::Group::ExternalStreamingDestination/#{id}"
        end

        # The path to get a group audit event destination via the GraphQL API
        #
        # @return [String]
        def api_get_path
          "/graphql"
        end

        # The path to create a group audit event destination via the GraphQL API (same as the GET path)
        #
        # @return [String]
        def api_post_path
          api_get_path
        end

        # The path to delete a group audit event destination via the GraphQL API (same as the GET path)
        #
        # @return [String]
        def api_delete_path
          api_get_path
        end

        # All audit event streaming destinations for a group
        #
        # @param [QA::Resource::Group] group the group to query destinations for
        # @return [Array<Hash>] array of destination data
        def all(group:)
          response = api_post_to(
            api_get_path,
            <<~GQL
              query {
                group(fullPath: "#{group.full_path}") {
                  id
                  externalAuditEventStreamingDestinations {
                    nodes {
                      id
                      name
                      category
                      config
                      secretToken
                      eventTypeFilters
                      active
                      namespaceFilters {
                        id
                        namespace {
                          id
                          fullPath
                        }
                      }
                    }
                  }
                }
              }
            GQL
          )

          response.dig(:external_audit_event_streaming_destinations, :nodes) || []
        end

        # Graphql mutation to create an audit event streaming destination
        #
        # @return [String]
        def api_post_body
          <<~GQL
            mutation {
              groupAuditEventStreamingDestinationsCreate(input: { #{mutation_params} }) {
                errors
                externalAuditEventDestination {
                  id
                  name
                  category
                  config
                  secretToken
                  active
                  group {
                    name
                  }
                }
              }
            }
          GQL
        end

        # Graphql mutation to delete an audit event streaming destination
        #
        # @return [String]
        def api_delete_body
          <<~GQL
            mutation {
              groupAuditEventStreamingDestinationsDelete(input: { id: "#{gid}" }) {
                errors
              }
            }
          GQL
        end

        # Graphql mutation to update an audit event streaming destination
        #
        # @param [Hash] params parameters to update
        # @return [Hash]
        def update(params = {})
          mutation = <<~GQL
            mutation {
              groupAuditEventStreamingDestinationsUpdate(input: {
                id: "#{gid}"
                #{update_mutation_params(params)}
              }) {
                errors
                externalAuditEventDestination {
                  id
                  name
                  category
                  config
                  secretToken
                  active
                }
              }
            }
          GQL
          response = api_post_to(api_get_path, mutation)
          process_api_response(response)
        end

        # Activate the destination
        #
        # @return [Hash]
        def activate!
          update(active: true)
        end

        # Deactivate the destination
        #
        # @return [Hash]
        def deactivate!
          update(active: false)
        end

        # Add headers to the destination by updating the config
        # For the new streaming model, headers are stored in config
        #
        # @param [Hash] headers hash of header name => value pairs
        # @return [Hash]
        def add_headers(headers)
          current_config = parse_config

          # Format headers for the new structure
          # Each header needs to be an object with 'value' and 'active' keys
          formatted_headers = headers.transform_keys(&:to_s).transform_values do |value|
            { 'value' => value.to_s, 'active' => true }
          end

          current_config['headers'] = formatted_headers

          # Update the destination with new config
          update(config: current_config)
        end

        # Graphql mutation to add event type filters
        #
        # @return [Hash]
        def add_filters(filters)
          mutation = <<~GQL
            mutation {
              auditEventsGroupDestinationEventsAdd(input: {
                destinationId: "#{gid}",
                eventTypeFilters: ["#{filters.join('","')}"]
              }) {
                errors
                eventTypeFilters
              }
            }
          GQL
          api_post_to(api_get_path, mutation)
        end

        # Graphql mutation to add namespace filters
        #
        # @param [Array<String>] namespace_paths array of namespace full paths
        # @return [Array<Hash>]
        def add_namespace_filters(namespace_paths)
          namespace_paths.map do |namespace_path|
            mutation = <<~GQL
              mutation {
                auditEventsGroupDestinationNamespaceFilterCreate(input: {
                  destinationId: "#{gid}",
                  namespacePath: "#{namespace_path}"
                }) {
                  errors
                  namespaceFilter {
                    id
                    namespace {
                      id
                      fullPath
                    }
                  }
                }
              }
            GQL
            api_post_to(api_get_path, mutation)
          end
        end

        def process_api_response(parsed_response)
          event_response = if parsed_response.key?(:external_audit_event_destination)
                             extract_graphql_resource(parsed_response, 'external_audit_event_destination')
                           else
                             parsed_response
                           end

          super(event_response)
        end

        protected

        # Return fields for comparing resources
        #
        # @return [Hash]
        def comparable
          reload! if api_response.nil?

          api_resource
        end

        private

        # Parse config whether it's a Hash or JSON string
        #
        # @return [Hash]
        def parse_config
          if config.is_a?(Hash)
            config.dup
          elsif config.is_a?(String)
            JSON.parse(config)
          else
            {}
          end
        end

        # Return available parameters formatted to be used in a GraphQL query
        #
        # @return [String]
        def mutation_params
          params = [
            %(groupPath: "#{group.full_path}"),
            %(category: "#{category}"),
            %(config: #{format_config})
          ]

          params << %(name: "#{name}") if defined?(@name) && @name.present?
          params << %(secretToken: "#{@secret_token}") if defined?(@secret_token) && @secret_token.present?

          params.join(', ')
        end

        # Return update parameters formatted to be used in a GraphQL query
        #
        # @param [Hash] params parameters to update
        # @return [String]
        def update_mutation_params(params)
          update_params = []

          update_params << %(name: "#{params[:name]}") if params.key?(:name)
          update_params << %(category: "#{params[:category]}") if params.key?(:category)
          update_params << %(config: #{format_config(params[:config])}) if params.key?(:config)
          update_params << %(secretToken: "#{params[:secret_token]}") if params.key?(:secret_token)
          update_params << %(active: #{params[:active]}) if params.key?(:active)

          update_params.join("\n")
        end

        # Format config as JSON for GraphQL
        #
        # @param [Hash] config_value optional config value to format
        # @return [String]
        def format_config(config_value = nil)
          config_to_format = config_value || config

          # Convert Ruby hash to JSON string for GraphQL
          if config_to_format.is_a?(Hash)
            # For GraphQL, we need to format as JSON object literal
            config_json = config_to_format.to_json
            # GraphQL expects JSON as a string value
            config_json.inspect
          else
            config_to_format.inspect
          end
        end

        # Standardize keys as snake case
        #
        # @return [Hash]
        def transform_api_resource(api_resource)
          api_resource.deep_transform_keys { |key| key.to_s.underscore.to_sym }
        end
      end
    end
  end
end
