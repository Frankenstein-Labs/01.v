# frozen_string_literal: true

require 'spec_helper'

# NOTE: This spec cannot use let_it_be because, because that doesn't work when using the `custom_repo` trait of
#       the project factory and subsequently modifying it, because it's a real on-disk repo at `tmp/tests/gitlab-test/`,
#       and any changes made to it are not reverted by let it be (even with reload). This means we also cannot use
#       these `let` declarations in a `before` context, so any mocking of them must occur in the examples themselves.
# NOTE: The fixture setup in this spec is complex, so we use let instead of let_it_be, so it's easier to reason about
# noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::Main, :freeze_time, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:user) { create(:user) }
  let(:group) { create(:group, name: 'test-group', developers: user) }
  let(:random_string) { "miraclefruit-camel-slategrey" }
  let(:project_ref) { 'master' }
  let(:devfile_path) { '.devfile.yaml' }
  let(:devfile_fixture_name) { 'example.devfile.yaml.erb' }
  let(:gitlab_kas_external_url) { "ws://kas.example.com/-/external/namespace/path" }
  let(:devfile_yaml) { read_devfile_yaml(devfile_fixture_name) }
  let(:expected_processed_devfile) { example_processed_devfile }
  let(:logger) { instance_double(Logger) }
  let(:variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT' },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT' }
    ]
  end

  let(:default_devfile_yaml) { example_default_devfile_yaml }

  let(:project) do
    files = devfile_path.nil? ? {} : { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let(:agent) do
    agent = create(:cluster_agent, project: project, created_by_user: user)
    create(:workspaces_agent_config, :with_overrides_for_all_possible_config_values, agent: agent)
    create(
      :organization_cluster_agent_mapping,
      user: user,
      agent: agent,
      organization: project.organization
    )
    agent.reload
  end

  let(:params) do
    {
      agent: agent,
      user: user,
      project: project,
      desired_state: states_module::RUNNING,
      project_ref: project_ref,
      devfile_path: devfile_path,
      variables: variables
    }
  end

  let(:tools_injector_image_from_settings) do
    workspace_operations_constants_module::WORKSPACE_TOOLS_IMAGE
  end

  let(:vscode_extension_marketplace) do
    {
      service_url: "https://open-vsx.org/vscode/gallery",
      item_url: "https://open-vsx.org/vscode/item",
      resource_url_template: "https://open-vsx.org/vscode/unpkg/{publisher}/{name}/{versionRaw}/{path}"
    }
  end

  let(:settings) do
    {
      tools_injector_image: tools_injector_image_from_settings,
      default_devfile_yaml: default_devfile_yaml,
      gitlab_kas_external_url: gitlab_kas_external_url
    }
  end

  let(:vscode_extension_marketplace_metadata_enabled) { false }

  let(:context) do
    {
      user: user,
      params: params,
      internal_events_class: Gitlab::InternalEvents,
      settings: settings,
      vscode_extension_marketplace: vscode_extension_marketplace,
      vscode_extension_marketplace_metadata: { enabled: vscode_extension_marketplace_metadata_enabled },
      logger: logger
    }
  end

  shared_examples 'tracks successful workspace creation event' do
    it "tracks creation event" do
      expect { response }
        .to trigger_internal_events('create_workspace_result')
        .with(
          category: 'RemoteDevelopment::WorkspaceOperations::Create::WorkspaceObserver',
          user: user,
          project: project,
          namespace: project.namespace,
          additional_properties: { label: 'succeed' }
        )
        .and increment_usage_metrics("counts.count_total_succeed_workspaces_created")
    end
  end

  shared_examples 'tracks failed workspace creation event' do |error_message|
    it "tracks failed creation event with proper error details" do
      expect { response }
        .to trigger_internal_events('create_workspace_result')
        .with(
          category: 'RemoteDevelopment::WorkspaceOperations::Create::WorkspaceErrorsObserver',
          user: user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'failed',
            property: error_message
          }
        )
        .and increment_usage_metrics("counts.count_total_failed_workspaces_created")
    end
  end

  subject(:response) do
    described_class.main(context)
  end

  context 'when params are valid' do
    before do
      allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
      allow(FFaker::Food).to receive(:fruit).and_return("Miracle Fruit")
      allow(FFaker::AnimalUS).to receive(:common_name).and_return("Camel")
      allow(FFaker::Color).to receive(:name).and_return("Slategrey")
    end

    context 'when devfile is valid' do
      # NOTE: The PaperTrail version value on workspaces_agent_config.versions.size is `2` on the created record. This
      #       is because the record is created by FactoryBot, then re-saved by Updater class in factory after(:create).
      #       This seems to be unavoidable due to the way PaperTrail works and the hooks that FactoryBot provides.
      #       See corresponding comment in `workspaces_agent_configs.rb` factory.
      let(:expected_workspaces_agent_config_version) { 2 }

      it 'creates a new workspace and returns success', :aggregate_failures do
        # NOTE: This example is structured and ordered to give useful and informative error messages in case of failures
        expect { response }.to change { RemoteDevelopment::Workspace.count }.by(1)

        expect(response.fetch(:status)).to eq(:success)
        expect(response[:message]).to be_nil
        expect(response[:payload]).not_to be_nil
        expect(response[:payload][:workspace]).not_to be_nil

        workspace = response.fetch(:payload).fetch(:workspace)
        expect(workspace.user).to eq(user)
        expect(workspace.agent).to eq(agent)
        expect(workspace.desired_state).to eq(states_module::RUNNING)
        # noinspection RubyResolve
        expect(workspace.desired_state_updated_at).to eq(Time.current)
        expect(workspace.actual_state).to eq(states_module::CREATION_REQUESTED)
        expect(workspace.actual_state_updated_at).to eq(Time.current)
        expect(workspace.name).to eq(random_string)
        expect(workspace.namespace)
          .to eq("#{create_constants_module::NAMESPACE_PREFIX}-#{random_string}")
        expect(workspace.workspaces_agent_config_version).to eq(expected_workspaces_agent_config_version)
        expect(workspace.url).to eq(URI::HTTPS.build({
          host: "#{create_constants_module::WORKSPACE_EDITOR_PORT}-#{workspace.name}." \
            "#{agent.unversioned_latest_workspaces_agent_config.dns_zone}",
          path: '/',
          query: {
            folder: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/#{project.path}"
          }.to_query
        }).to_s)
        # noinspection RubyResolve
        expect(workspace.devfile).to eq(devfile_yaml)

        actual_processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
        expect(actual_processed_devfile).to eq(expected_processed_devfile)

        variables.each do |variable|
          expect(
            RemoteDevelopment::WorkspaceVariable.where(
              workspace: workspace,
              key: variable[:key],
              variable_type:
                RemoteDevelopment::Enums::WorkspaceVariable::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL[variable[:type]]
            ).first&.value
          ).to eq(variable[:value])
        end

        expect(workspace.workspace_agentk_state).to be_present
        expect(workspace.workspace_agentk_state.desired_config).to be_an(Array)
      end

      it_behaves_like 'tracks successful workspace creation event'

      context 'with versioned workspaces_agent_configs behavior' do
        before do
          agent.unversioned_latest_workspaces_agent_config.touch
        end

        let(:expected_workspaces_agent_config_version) { 3 }

        it 'creates a new workspace with latest workspaces_agent_config version' do
          workspace = response.fetch(:payload).fetch(:workspace)
          expect(workspace.workspaces_agent_config_version).to eq(expected_workspaces_agent_config_version)
        end

        it_behaves_like 'tracks successful workspace creation event'
      end

      context "with shared namespace" do
        before do
          # max_resources_per_workspace must be an empty hash if shared_namespace is specified
          agent.unversioned_latest_workspaces_agent_config.update!(
            shared_namespace: "default",
            max_resources_per_workspace: {}
          )
        end

        it 'uses a unique namespace', :aggregate_failures do
          workspace = response.fetch(:payload).fetch(:workspace)
          expect(workspace.namespace).to eq("default")
        end

        it_behaves_like 'tracks successful workspace creation event'
      end
    end

    context 'when devfile_path is nil' do
      let(:devfile_path) { nil }

      it 'creates a new workspace using default_devfile_yaml from settings' do
        workspace = response.fetch(:payload).fetch(:workspace)

        expect(workspace.devfile).to eq(default_devfile_yaml)
      end

      it_behaves_like 'tracks successful workspace creation event'
    end

    context 'when devfile is not valid', :aggregate_failures do
      let(:devfile_fixture_name) { 'example.invalid-components-entry-missing-devfile.yaml.erb' }

      it 'does not create the workspace and returns error' do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Devfile restrictions failed: No components present in devfile",
          reason: :bad_request
        })
      end

      it_behaves_like 'tracks failed workspace creation event', 'DevfileRestrictionsFailed'
    end
  end

  context 'when params are invalid' do
    context 'when devfile is not found' do
      let(:devfile_path) { 'not-found.yaml' }

      before do
        allow(project.repository).to receive(:blob_at_branch).and_return(nil)
      end

      it 'does not create the workspace and returns error', :aggregate_failures do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create devfile load failed: Devfile path '#{devfile_path}' at ref '#{project_ref}' " \
            "does not exist in the project repository",
          reason: :bad_request
        })
      end

      it_behaves_like 'tracks failed workspace creation event', 'WorkspaceCreateDevfileLoadFailed'
    end

    context 'when agent has no associated config' do
      let(:agent) do
        agent = create(:cluster_agent, name: "007")
        create(
          :organization_cluster_agent_mapping,
          user: user,
          agent: agent,
          organization: project.organization
        )
        agent
      end

      it 'does not create the workspace and returns error' do
        # confirm fixture value
        expect(agent.unversioned_latest_workspaces_agent_config).to be_nil

        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create params validation failed: No WorkspacesAgentConfig found for agent '007'",
          reason: :bad_request
        })
      end

      it_behaves_like 'tracks failed workspace creation event', 'WorkspaceCreateParamsValidationFailed'
    end
  end

  context "when vscode_extension_marketplace_metadata Web IDE setting is disabled" do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }
    let(:vscode_extension_marketplace_metadata_enabled) { false }

    it 'uses image override' do
      tools_injector_component_name =
        create_constants_module::TOOLS_INJECTOR_COMPONENT_NAME
      workspace = response.fetch(:payload).fetch(:workspace)
      processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
      image_from_processed_devfile =
        processed_devfile.fetch(:components)
                         .find { |component| component.fetch(:name) == tools_injector_component_name }
                         .dig(:container, :image)
      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end

    it_behaves_like 'tracks successful workspace creation event'
  end
end
