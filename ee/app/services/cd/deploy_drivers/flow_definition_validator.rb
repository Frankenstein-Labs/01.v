# frozen_string_literal: true

module Cd
  module DeployDrivers
    # Two layers: the whole document against the orchestration engine's schema, then
    # driver-owned parts against the driver's. The document layer runs first and stops the
    # pass, since a document the engine rejects has none of the shape the driver walk
    # assumes. Run at rollout start, so a driver rebinding cannot leave a stale config
    # undetected.
    class FlowDefinitionValidator
      def initialize(document:, drivers:)
        @document = document
        @drivers = drivers
      end

      def errors
        @errors ||= collect_errors
      end

      def valid?
        errors.empty?
      end

      private

      attr_reader :document, :drivers

      def collect_errors
        return [] if document.nil?

        document_errors = schema_errors(flow_definition_schemer, document, 'flow definition')
        return document_errors if document_errors.any?

        [*environment_service_errors(document), *step_errors(document)]
      end

      def environment_service_errors(document)
        document.fetch('environments', {}).flat_map do |environment_name, environment_config|
          next [] unless environment_config.is_a?(Hash)

          environment_config.fetch('services', {}).flat_map do |service_name, service_environment|
            schema_errors_any(application_environment_schemers, service_environment,
              "environment '#{environment_name}' service '#{service_name}'")
          end
        end
      end

      def step_errors(document)
        ::Cd::ApplicationFlowDefinitions::Document.new(document).driver_steps.flat_map do |step|
          schema_errors_any(steps_schemers, step, "step targeting environment '#{step['environment']}'")
        end
      end

      # Compiled once, not per step and per service.
      def flow_definition_schemer
        @flow_definition_schemer ||= JSONSchemer.schema(::Cd::DeployDrivers::Registry.orchestrator.flow_definition_schema)
      end

      def application_environment_schemers
        @application_environment_schemers ||= drivers.map do |driver|
          JSONSchemer.schema(driver.application_environment_schema)
        end
      end

      def steps_schemers
        @steps_schemers ||= drivers.map { |driver| JSONSchemer.schema(driver.steps_schema) }
      end

      def schema_errors(schemer, value, context)
        schemer.validate(value).map { |error| "#{context}: #{error['error']}" }
      end

      def schema_errors_any(schemers, value, context)
        return [] if schemers.empty? || schemers.any? { |schemer| schemer.valid?(value) }

        schema_errors(schemers.first, value, context)
      end
    end
  end
end
