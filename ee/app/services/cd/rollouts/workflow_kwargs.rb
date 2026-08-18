# frozen_string_literal: true

module Cd
  module Rollouts
    # Builds the AutoFlow kwargs describing a rollout's target clusters, deploy
    # pipeline and version set. Passed to Gitlab::Kas::Client#start_workflow by
    # Cd::Rollouts::StartService
    class WorkflowKwargs
      InvalidConfigError = Class.new(StandardError)

      def initialize(rollout)
        @rollout = rollout
      end

      def to_h
        {
          'rollout_id' => rollout.id.to_s,
          'organization_id' => rollout.organization_id.to_s,
          'flow_definition' => flow_definition,
          'environments' => environments,
          'version_set' => version_set
        }
      end

      private

      attr_reader :rollout

      # Keyed by environment name so the driver can join the pipeline's own
      # `environments` map (manifest repository config, keyed the same way) with
      # the cluster each environment deploys to.
      def environments
        rollout_environments = rollout
          .rollout_environments
          .ordered
          .preload_environment_and_driver_binding

        rollout_environments.each_with_object({}) do |rollout_environment, memo|
          memo[rollout_environment.environment.name] = {
            'cluster_agent_id' => fetch_config(
              rollout_environment.driver_binding.driver_config, 'cluster_agent_id'
            )
          }
        end
      end

      # Passed through verbatim; the engine walks flow_definition.steps and a driver
      # resolves manifests via flow_definition.environments.
      def flow_definition
        YAML.safe_load(rollout.application_flow_definition.definition)
      rescue Psych::Exception => e
        raise InvalidConfigError, "Rollout #{rollout.id} has an unparseable flow definition: #{e.message}"
      end

      def version_set
        entries_by_service = rollout
          .version_set
          .version_set_entries
          .preload_version_and_service_and_artifact_source
          .group_by(&:service)

        services = entries_by_service.map do |service, entries|
          artifacts = entries.map do |entry|
            source_config = entry.artifact_source.source_config

            {
              'name' => fetch_config(source_config, 'name'),
              'version' => entry.version.name,
              'source' => {
                'type' => fetch_config(source_config, 'type'),
                'image' => entry.artifact_source.source_ref
              }
            }
          end

          { 'name' => service.name, 'artifacts' => artifacts }
        end

        { 'services' => services }
      end

      def fetch_config(config, key)
        config.fetch(key) { raise InvalidConfigError, "Missing required config key '#{key}' in #{config.inspect}" }
      end
    end
  end
end
