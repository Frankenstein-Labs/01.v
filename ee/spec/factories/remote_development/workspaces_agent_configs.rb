# frozen_string_literal: true

FactoryBot.define do
  # noinspection RubyResolve -- RubyMine is not finding the model attributes
  factory :workspaces_agent_config, class: 'RemoteDevelopment::WorkspacesAgentConfig' do
    agent factory: :cluster_agent
    enabled { true }
    dns_zone { 'workspaces.localdev.me' }

    after(:build) do |workspaces_agent_config, _evaluator|
      workspaces_agent_config.project_id = workspaces_agent_config.agent.project_id
    end

    trait :with_overrides_for_all_possible_config_values do
      # NOTE: This trait will result in the PaperTrail version value in
      #       workspaces_agent_config.versions.size value being 2 on the created record.
      #       This is because the record is created here by FactoryBot, then re-saved here by the Updater class.
      #       This seems to be unavoidable due to the way PaperTrail works and the hooks that FactoryBot provides.
      #       (no, 'to_create' doesn't seem to work either).
      after(:create) do |workspaces_agent_config, _evaluator|
        config_yaml = File.read("ee/spec/fixtures/remote_development/example.agent_config.yaml")
        config = YAML.safe_load(config_yaml)
        logger = instance_double(::Logger).tap do |logger|
          allow(logger).to receive(:warn)
        end

        # Use the actual updater class to parse the YAML and set the values
        context = {
          agent: workspaces_agent_config.agent,
          config: config,
          logger: logger
        }

        result = RemoteDevelopment::AgentConfigOperations::Updater.update(context)

        raise result.unwrap_err.to_s if result.err?

        workspaces_agent_config.reload
        workspaces_agent_config.agent.reload
      end
    end
  end
end
