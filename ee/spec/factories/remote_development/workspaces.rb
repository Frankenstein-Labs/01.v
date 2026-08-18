# frozen_string_literal: true

FactoryBot.define do
  # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
  factory :workspace, class: 'RemoteDevelopment::Workspace' do
    # noinspection RailsParamDefResolve -- RubyMine flags this as requiring a hash, but a symbol is a valid option
    association :project, :in_group
    user
    agent factory: [:ee_cluster_agent, :with_existing_workspaces_agent_config]
    personal_access_token

    name { "workspace-#{agent.id}-#{user.id}-#{random_string}" }
    force_include_all_resources { true }

    add_attribute(:namespace) do
      namespace_prefix = RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::NAMESPACE_PREFIX
      "#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}"
    end

    desired_state { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
    actual_state { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
    deployment_resource_version { 2 }

    project_ref { 'main' }
    devfile_path { '.devfile.yaml' }

    devfile do
      RemoteDevelopment::FixtureFileHelpers.read_devfile_yaml('example.devfile.yaml.erb')
    end

    processed_devfile do
      RemoteDevelopment::FixtureFileHelpers.read_devfile_yaml('example.processed-devfile.yaml.erb')
    end

    transient do
      random_string { SecureRandom.alphanumeric(6).downcase }
      without_workspace_agentk_state { false }
      without_workspace_variables { false }
      without_realistic_after_create_timestamp_updates { false }
      after_initial_reconciliation { false }
      unprovisioned { false }
    end

    trait :without_workspace_agentk_state do
      transient do
        without_workspace_agentk_state { true }
      end
    end

    trait :without_workspace_variables do
      transient do
        without_workspace_variables { true }
      end
    end

    # Use this trait if you want to directly control any timestamp fields when invoking the factory.
    trait :without_realistic_after_create_timestamp_updates do
      transient do
        without_realistic_after_create_timestamp_updates { true }
      end
    end

    # Use this trait if you want to simulate workspace state just after one round of reconciliation where
    # agent has already received config to apply from Rails
    trait :after_initial_reconciliation do
      transient do
        after_initial_reconciliation { true }
      end
    end

    trait :unprovisioned do
      desired_state { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
      actual_state { RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED }
      responded_to_agent_at { nil }
      deployment_resource_version { nil }

      transient do
        unprovisioned { true }
      end
    end

    after(:build) do |workspace, _|
      user = workspace.user
      workspace.project.add_developer(user)
      workspace.agent.project.add_developer(user)
      workspace.url_prefix ||=
        "#{RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_EDITOR_PORT}-#{workspace.name}"
      workspace.url_query_string ||= "folder=dir%2Ffile"
    end

    after(:create) do |workspace, evaluator|
      if evaluator.without_realistic_after_create_timestamp_updates
        # Set responded_to_agent_at to a non-nil value unless it has already been set
        workspace.update!(responded_to_agent_at: workspace.updated_at) unless workspace.responded_to_agent_at
      elsif evaluator.after_initial_reconciliation
        # The most recent activity was reconciliation where info for the workspace was reported to the agent
        # This DOES NOT necessarily mean that the actual and desired states for the workspace are now the same
        # This is because successful convergence of actual & desired states may span more than 1 reconciliation cycle
        workspace.update!(
          desired_state_updated_at: 2.seconds.ago,
          actual_state_updated_at: 3.seconds.ago,
          responded_to_agent_at: 1.second.ago
        )
      else
        unless evaluator.without_workspace_variables
          workspace_name = workspace.name
          dns_zone = workspace.workspaces_agent_config.dns_zone
          gitlab_workspaces_proxy_http_enabled = workspace.workspaces_agent_config.gitlab_workspaces_proxy_http_enabled
          domain_template = RemoteDevelopment::WorkspaceOperations::WorkspaceUrlHelper.url_template(
            workspace_name,
            dns_zone,
            gitlab_workspaces_proxy_http_enabled
          )
          common_host_prefix =
            RemoteDevelopment::WorkspaceOperations::WorkspaceUrlHelper.common_workspace_host_suffix?(
              gitlab_workspaces_proxy_http_enabled
            )

          workspace_token = ""
          # The model's before_save and after_save ensures that the token is only associated for workspaces who are
          # in the running state.
          if common_host_prefix && workspace.desired_state == RemoteDevelopment::WorkspaceOperations::States::RUNNING
            workspace_token = workspace.workspace_token.token
          end

          workspace_variables = RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesBuilder.build(
            domain_template: domain_template,
            gitlab_kas_external_url: RemoteDevelopment::Settings.get_single_setting(:gitlab_kas_external_url),
            personal_access_token_value: workspace.personal_access_token.token,
            user_name: workspace.user.name,
            user_email: workspace.user.email,
            workspace_id: workspace.id,
            workspace_token: workspace_token,
            vscode_extension_marketplace: ::WebIde::ExtensionMarketplacePreset.open_vsx.values,
            variables: []
          )

          workspace_variables.each do |workspace_variable|
            workspace.workspace_variables.create!(workspace_variable)
          end
        end

        if workspace.desired_state == workspace.actual_state
          # The most recent activity was a poll that reconciled the desired and actual state.
          desired_state_updated_at = 3.seconds.ago
          actual_state_updated_at = 2.seconds.ago
          responded_to_agent_at = 1.second.ago
        else
          # The most recent activity was a user action which updated the desired state to be different
          # than the actual state.
          desired_state_updated_at = 1.second.ago
          actual_state_updated_at = 3.seconds.ago
          responded_to_agent_at = 2.seconds.ago
        end

        workspace.update!(
          # NOTE: created_at and updated_at are not currently used in any logic, but we set them to be
          #       before desired_state_updated_at or responded_to_agent_at to ensure the record represents
          #       a realistic condition.
          created_at: 4.seconds.ago,
          updated_at: 4.seconds.ago,

          desired_state_updated_at: desired_state_updated_at,
          actual_state_updated_at: actual_state_updated_at,
          responded_to_agent_at: responded_to_agent_at
        )
      end

      unless evaluator.without_workspace_agentk_state
        # NOTE: We could attempt to manually build a desired_config_array which has all the correct IDs and values
        #       agent, namespace, workspace, etc, but this would be a lot of work. For now, we will just use the
        #       business logic to create a valid one based on the workspace's current state and associations.
        result = RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main.main({
          params: {
            agent: workspace.agent
          },
          workspace: workspace,
          logger: nil
        })
        desired_config_array = result.fetch(:desired_config).symbolized_desired_config_array

        workspace.create_workspace_agentk_state!(
          project: workspace.project,
          desired_config: desired_config_array
        )
      end

      if evaluator.unprovisioned
        # if the workspace is unprovisioned, set responded_to_agent_at to nil
        workspace.update!(responded_to_agent_at: nil)
      end
    end
  end
end
