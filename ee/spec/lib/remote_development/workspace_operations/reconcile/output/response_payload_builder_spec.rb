# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadBuilder, feature_category: :workspaces do
  include_context "with constant modules"

  let(:update_types) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes }
  let(:logger) { instance_double(Logger) }
  let(:desired_state) { states_module::RUNNING }
  let(:actual_state) { states_module::STOPPED }
  let(:force_include_all_resources) { false }
  let(:image_pull_secrets) { [{ name: "secret-name", namespace: "secret-namespace" }] }

  let(:agent_config) do
    instance_double(
      "RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      image_pull_secrets: image_pull_secrets
    )
  end

  # TODO: remove this after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
  let(:workspace_agentk_state) { nil }

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      id: 1,
      name: "workspace",
      namespace: "namespace",
      deployment_resource_version: "1",
      desired_state: desired_state,
      actual_state: actual_state,
      force_include_all_resources: force_include_all_resources,
      workspaces_agent_config: agent_config,
      # TODO: remove this after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
      workspace_agentk_state: workspace_agentk_state
    )
  end

  let(:settings) do
    {
      full_reconciliation_interval_seconds: 3600,
      partial_reconciliation_interval_seconds: 10
    }
  end

  let(:context) do
    {
      update_type: update_type,
      workspaces_to_be_returned: [workspace],
      settings: settings,
      logger: logger
    }
  end

  let(:desired_config_array) { [{}] }
  let(:desired_config_array_is_valid) { true }

  let(:desired_config) do
    instance_double(
      "RemoteDevelopment::WorkspaceOperations::DesiredConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      desired_config_array: desired_config_array
    )
  end

  # NOTE: We are setting `expected_include_all_resources` into our fake `generated_config_to_apply` which is mocked to
  #       be returned from DesiredConfigGenerator. This allows us to perform assertions on the expected passed/returned
  #       value of `include_all_resources` using simple `let` statements, and avoid having to write complex mocks.
  let(:generated_config_to_apply) do
    [
      {
        include_all_resources: expected_include_all_resources,
        some_other_key: 1
      }
    ]
  end

  let(:expected_generated_config_to_apply) { generated_config_to_apply }

  let(:expected_returned_workspace_rails_infos) do
    config_to_apply_yaml_stream = expected_generated_config_to_apply&.map do |resource|
      YAML.dump(resource.deep_stringify_keys)
    end&.join

    [
      {
        name: workspace.name,
        namespace: workspace.namespace,
        deployment_resource_version: workspace.deployment_resource_version,
        desired_state: desired_state,
        actual_state: actual_state,
        image_pull_secrets: image_pull_secrets,
        config_to_apply: config_to_apply_yaml_stream || ""
      }
    ]
  end

  let(:expected_returned_value) do
    context.merge(
      response_payload: {
        workspace_rails_infos: expected_returned_workspace_rails_infos,
        settings: settings
      },
      observability_for_rails_infos: {
        name: workspace.name,
        config_to_apply_resources_include_type: expected_workspace_resources_included_type
      }
    )
  end

  let(:expected_workspace_resources_included_type) do
    described_class::ALL_RESOURCES_INCLUDED
  end

  subject(:returned_value) do
    described_class.build(context)
  end

  before do
    allow(workspace)
      .to receive_messages(
        desired_state_updated_more_recently_than_last_response_to_agent?:
          desired_state_updated_more_recently_than_last_response_to_agent,
        actual_state_updated_more_recently_than_last_response_to_agent?:
          actual_state_updated_more_recently_than_last_response_to_agent,
        desired_state_terminated_and_actual_state_not_terminated?:
          desired_state_terminated_and_actual_state_not_terminated
      )

    allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigFetcher)
      .to receive(:fetch)
      .and_return(desired_config)

    allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ConfigToApplyBuilder)
      .to receive(:build)
      .with(desired_config: desired_config, workspace: workspace, include_all_resources: expected_include_all_resources)
      .and_return(generated_config_to_apply)

    allow_next_instance_of(
      RemoteDevelopment::WorkspaceOperations::DesiredConfig,
      desired_config_array: generated_config_to_apply
    ) do |instance|
      if desired_config_array_is_valid
        allow(instance).to receive(:validate!)
      else
        allow(instance).to receive(:validate!).and_raise("Validation failed")
      end
    end
  end

  context "when update_type is FULL" do
    let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
    let(:actual_state_updated_more_recently_than_last_response_to_agent) { false }
    let(:desired_state_terminated_and_actual_state_not_terminated) { false }
    let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::FULL }
    let(:expected_include_all_resources) { true }

    it "includes config_to_apply with all resources included" do
      expect(returned_value).to eq(expected_returned_value)
    end

    context "when config_to_apply contains multiple resources" do
      let(:generated_config_to_apply) do
        [
          {
            a: {
              z: 1,
              a: 1
            }
          },
          {
            b: 2
          }
        ]
      end

      let(:expected_generated_config_to_apply) do
        [
          {
            a: {
              a: 1,
              z: 1
            }
          },
          {
            b: 2
          }
        ]
      end

      it "includes all resources with hashes deep sorted" do
        expect(returned_value).to eq(expected_returned_value)
        returned_value[:response_payload][:workspace_rails_infos].first[:config_to_apply]
        returned_value => {
          response_payload: {
            workspace_rails_infos: [
              {
                config_to_apply: config_to_apply_yaml_stream
              },
            ]
          }
        }
        loaded_multiple_docs = YAML.load_stream(config_to_apply_yaml_stream)
        expect(loaded_multiple_docs.size).to eq(expected_generated_config_to_apply.size)
      end
    end

    context "when generated config_to_apply is not valid" do
      # TODO: remove this 'let' after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
      let(:workspace_agentk_state) do
        instance_double(
          "RemoteDevelopment::WorkspaceAgentkState", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          desired_config: generated_config_to_apply
        )
      end

      let(:desired_config_array_is_valid) { false }

      it "raises an error" do
        expect { returned_value }.to raise_error(/Validation failed/)
      end
    end
  end

  context "when update_type is PARTIAL" do
    let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::PARTIAL }

    using RSpec::Parameterized::TableSyntax

    where(
      :force_include_all_resources,
      :desired_state_updated_more_recently_than_last_response_to_agent,
      :actual_state_updated_more_recently_than_last_response_to_agent,
      :desired_state_terminated_and_actual_state_not_terminated,
      :expected_include_all_resources,
      :expected_workspace_resources_included_type,
      :expect_config_to_apply_to_be_included
    ) do
      # @formatter:off - Turn off RubyMine autoformatting
      true  | true  | false | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      true  | false | false | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      false | true  | false | false | false | described_class::PARTIAL_RESOURCES_INCLUDED | true
      false | false | false | false | false | described_class::NO_RESOURCES_INCLUDED      | false
      false | false | false | true  | false | described_class::PARTIAL_RESOURCES_INCLUDED | true
      true  | true  | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      true  | false | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      false | true  | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      false | false | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
      # @formatter:on
    end

    with_them do
      let(:generated_config_to_apply) { nil } unless params[:expect_config_to_apply_to_be_included]

      it { expect(returned_value).to eq(expected_returned_value) }
    end
  end
end
