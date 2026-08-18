# frozen_string_literal: true

require 'spec_helper'

# NOTE: The fixture setup in this spec is complex, so we use let instead of let_it_be, so it's easier to reason about
# rubocop:disable RSpec/MultipleMemoizedHelpers -- needed helpers for multiple cases
# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
# noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Main, "Integration", :freeze_time, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:user) { create(:user) }
  let(:agent) do
    agent = create(:cluster_agent)
    create(:workspaces_agent_config, :with_overrides_for_all_possible_config_values, agent: agent)
    agent.reload
  end

  let_it_be(:project) { create(:project, path: "test-project") }

  let(:desired_state) { states_module::STOPPED }
  let(:actual_state) { states_module::STOPPED }
  let(:force_include_all_resources) { false }
  let(:workspace_fixture_common_args) do
    {
      user: user,
      agent: agent,
      project: project,
      desired_state: desired_state,
      actual_state: actual_state,
      force_include_all_resources: force_include_all_resources
    }
  end

  let(:workspace) do
    create(
      :workspace,
      **workspace_fixture_common_args
    )
  end

  let(:workspace_agent_info) do
    create_workspace_agent_info_hash(
      workspace: workspace.reload,
      previous_actual_state: previous_actual_state,
      current_actual_state: current_actual_state,
      workspace_exists: workspace_exists,
      resource_version: deployment_resource_version_from_agent,
      error_details: error_from_agent
    )
  end

  let(:expected_config_to_apply_include_all_resources) { false }
  let(:unversioned_latest_workspaces_agent_config) { agent.unversioned_latest_workspaces_agent_config }
  let(:dns_zone) { unversioned_latest_workspaces_agent_config.dns_zone }
  let(:default_runtime_class) { unversioned_latest_workspaces_agent_config.default_runtime_class }
  let(:image_pull_secrets) { unversioned_latest_workspaces_agent_config.image_pull_secrets.map(&:deep_symbolize_keys) }
  let(:egress_ip_rules) { unversioned_latest_workspaces_agent_config.network_policy_egress.map(&:deep_symbolize_keys) }
  let(:labels) do
    unversioned_latest_workspaces_agent_config.labels.deep_symbolize_keys
  end

  let(:agent_annotations) { unversioned_latest_workspaces_agent_config.annotations.deep_symbolize_keys }
  let(:max_resources_per_workspace) do
    unversioned_latest_workspaces_agent_config.max_resources_per_workspace.deep_symbolize_keys
  end

  let(:default_resources_per_workspace_container) do
    unversioned_latest_workspaces_agent_config.default_resources_per_workspace_container.deep_symbolize_keys
  end

  let(:full_reconciliation_interval_seconds) { 3600 }
  let(:partial_reconciliation_interval_seconds) { 10 }

  let(:logger) { instance_double(::Logger) }

  let(:user_defined_commands) do
    [
      {
        id: "db-component-command-with-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      },
      {
        id: "db-component-command-without-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the the container's default WORKDIR'",
          hotReloadCapable: false
        }
      },
      {
        id: "main-component-command-without-working-dir",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the projects/project_path directory'",
          hotReloadCapable: false
        }
      },
      {
        id: "user-defined-command",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      }
    ]
  end

  let(:expected_config_to_apply_yaml_stream) do
    create_config_to_apply_yaml_stream(
      workspace: workspace,
      started: expected_started,
      desired_state_is_terminated: expected_desired_state_is_terminated,
      include_all_resources: expected_config_to_apply_include_all_resources,
      dns_zone: dns_zone,
      default_runtime_class: default_runtime_class,
      agent_annotations: agent_annotations,
      agent_labels: labels,
      egress_ip_rules: egress_ip_rules,
      max_resources_per_workspace: max_resources_per_workspace,
      default_resources_per_workspace_container: default_resources_per_workspace_container,
      image_pull_secrets: image_pull_secrets,
      user_defined_commands: user_defined_commands
    )
  end

  let(:expected_desired_state) { desired_state }
  let(:expected_actual_state) { actual_state }
  let(:expected_started) { true }
  let(:expected_desired_state_is_terminated) { false }
  let(:expected_workspace_rails_infos) { [expected_workspace_rails_info] }

  let(:expected_workspace_rails_info) do
    {
      name: workspace.name,
      namespace: workspace.namespace,
      desired_state: expected_desired_state,
      actual_state: expected_actual_state,
      deployment_resource_version: expected_deployment_resource_version,
      config_to_apply: expected_config_to_apply_yaml_stream,
      image_pull_secrets: image_pull_secrets
    }
  end

  subject(:response) do
    # Ensure workspace and other fixtures are created before starting reconciliation
    workspace

    described_class.main(
      agent: agent,
      logger: logger,
      original_params: {
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      },
      settings: {
        full_reconciliation_interval_seconds: full_reconciliation_interval_seconds,
        partial_reconciliation_interval_seconds: partial_reconciliation_interval_seconds
      }
    )
  end

  before do
    allow(logger).to receive(:debug)
  end

  shared_context "with unprovisioned workspace" do
    let(:expected_config_to_apply_include_all_resources) { true }
    let(:expected_deployment_resource_version) { nil }
    let(:expected_started) { false }
    let(:workspace_agent_infos) { [] }

    let(:workspace) do
      create(:workspace, :unprovisioned, **workspace_fixture_common_args)
    end

    # rubocop:disable RSpec/ExpectInHook -- We are just confirming fixtures, no need to run these as a full example which would slow down the test, or to duplicate them in each example.
    before do
      # confirm fixture values
      expect(workspace.responded_to_agent_at).to be_nil
    end
    # rubocop:enable RSpec/ExpectInHook
  end

  shared_examples "unprovisioned workspace expectations" do
    it 'returns proper response payload' do
      # verify initial states in db (sanity check of match between factory and fixtures)
      expect(workspace.desired_state).to eq(desired_state)
      expect(workspace.actual_state).to eq(actual_state)

      expect(response[:message]).to be_nil
      workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
      expect(workspace_rails_infos.length).to eq(1)

      # test the config to apply first to get a more specific diff if it fails
      unprovisioned_workspace_rails_info =
        workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
      expect(unprovisioned_workspace_rails_info.fetch(:config_to_apply))
        .to eq(expected_workspace_rails_info.fetch(:config_to_apply))

      # then test everything in the infos
      expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
    end
  end

  shared_examples 'workspace lifecycle management expectations' do |expected_desired_state:|
    it "sets desired_state to #{expected_desired_state}" do
      expect(response[:message]).to be_nil

      response => {
        payload: {
          workspace_rails_infos: [
            *_,
            {
              desired_state: actual_desired_state
            },
            *_
          ]
        }
      }

      expect(actual_desired_state).to eq(expected_desired_state)

      expect(workspace.reload.desired_state).to eq(expected_desired_state)
    end
  end

  shared_examples 'includes settings in payload' do
    it 'returns expected settings' do
      settings = response.fetch(:payload).fetch(:settings)

      expect(settings[:full_reconciliation_interval_seconds]).to eq full_reconciliation_interval_seconds
      expect(settings[:partial_reconciliation_interval_seconds]).to eq partial_reconciliation_interval_seconds
    end
  end

  shared_examples 'versioned workspaces_agent_configs behavior' do
    let(:new_dns_zone) { 'new.dns.zone.me' }

    it 'uses versioned config values' do
      previous_dns_zone = agent.unversioned_latest_workspaces_agent_config.dns_zone

      response => {
        payload: {
          workspace_rails_infos: [
            *_,
            {
              config_to_apply: config_to_apply_yaml_stream
            },
            *_
          ]
        }
      }

      agent.unversioned_latest_workspaces_agent_config.update!(dns_zone: new_dns_zone)

      # Verify that the new versioned value is used in the agent config, and the previous versioned value
      # is used in the workspace. This is an attempt to avoid an occasional flake
      # where the tests seem to not detect the existence of the new paper_trail reified version. These assertions
      # will help narrow down if there is some race condition or caching issue with the versioning logic.
      expect(agent.unversioned_latest_workspaces_agent_config.dns_zone).to eq(new_dns_zone)
      expect(agent.workspaces.first.reload.workspaces_agent_config.dns_zone).to eq(previous_dns_zone)

      config_to_apply = yaml_safe_load_stream_symbolized(config_to_apply_yaml_stream)

      config_to_apply => [
        *_,
        {
          kind: "Service",
          metadata: {
            annotations: {
              "workspaces.gitlab.com/host-template": host_template_annotation
            }
          }
        },
        *_
      ]

      expect(host_template_annotation).to include(previous_dns_zone)
      expect(host_template_annotation).not_to include(new_dns_zone)
    end
  end

  context 'when update_type is full' do
    let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::FULL }
    let(:workspace_agent_infos) { [] }

    it 'returns expected keys within the response payload', :unlimited_max_formatted_output_length do
      expect(response.fetch(:payload).keys).to contain_exactly(:settings, :workspace_rails_infos)
    end

    it_behaves_like 'includes settings in payload'

    context 'when new unprovisioned workspace exists in database"' do
      include_context "with unprovisioned workspace"

      it_behaves_like 'unprovisioned workspace expectations'
      it_behaves_like 'versioned workspaces_agent_configs behavior'
    end

    context 'when workspace has user-defined postStart commands' do
      it 'includes user-defined commands in the scripts configmap' do
        workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
        actual_workspace_rails_info = workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
        actual_config_to_apply =
          yaml_safe_load_stream_symbolized(actual_workspace_rails_info.fetch(:config_to_apply))

        scripts_configmap = actual_config_to_apply.find do |resource|
          resource[:kind] == "ConfigMap" && resource[:metadata][:name].end_with?("-scripts-configmap")
        end

        expect(scripts_configmap).to be_present

        expect(scripts_configmap[:data].keys).to include(user_defined_commands.first[:id].to_sym)

        expect(scripts_configmap[:data][user_defined_commands.first[:id].to_sym]).to eq(
          user_defined_commands.first[:exec][:commandLine]
        )

        # Verify the poststart script includes the user-defined command
        poststart_script = scripts_configmap[:data][
          :"tooling-container-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}"
        ]
        expect(poststart_script).to include("Running /workspace-scripts/tooling-container/user-defined-command")
      end
    end
  end

  context 'when update_type is partial' do
    let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::PARTIAL }

    context 'when receiving agent updates for a workspace which exists in the db' do
      let(:desired_state) { states_module::STOPPED }
      let(:actual_state) { current_actual_state }
      let(:previous_actual_state) { states_module::STOPPING }
      let(:current_actual_state) { states_module::STOPPED }
      let(:workspace_exists) { false }
      let(:deployment_resource_version_from_agent) { '2' }
      let(:expected_deployment_resource_version) { deployment_resource_version_from_agent }
      let(:error_from_agent) { nil }
      let(:workspace_agent_infos) { [workspace_agent_info] }

      describe 'workspace lifecycle management' do
        let(:max_hours_before_termination) do
          RemoteDevelopment::WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION
        end

        let(:workspace) do
          workspace = create(
            :workspace,
            :without_realistic_after_create_timestamp_updates,
            created_at: created_at,
            **workspace_fixture_common_args
          )
          workspace.update!(desired_state_updated_at: desired_state_updated_at)
          workspace.update!(actual_state_updated_at: actual_state_updated_at)
          workspace
        end

        context 'when max_active_hours_before_stop has passed' do
          let(:desired_state) { states_module::RUNNING }
          let(:actual_state) { states_module::RUNNING }
          let(:created_at) { max_hours_before_termination.hours.ago + 1.minute }
          let(:desired_state_updated_at) do
            unversioned_latest_workspaces_agent_config.max_active_hours_before_stop.hours.ago - 70.seconds
          end

          let(:actual_state_updated_at) do
            unversioned_latest_workspaces_agent_config.max_active_hours_before_stop.hours.ago - 1.minute
          end

          it_behaves_like 'workspace lifecycle management expectations',
            expected_desired_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED
        end

        context 'when max_stopped_hours_before_termination has passed' do
          let(:desired_state) { states_module::STOPPED }
          let(:actual_state) { states_module::STOPPED }
          let(:created_at) { max_hours_before_termination.hours.ago + 1.minute }
          let(:desired_state_updated_at) do
            unversioned_latest_workspaces_agent_config.max_stopped_hours_before_termination.hours.ago - 70.seconds
          end

          let(:actual_state_updated_at) do
            unversioned_latest_workspaces_agent_config.max_stopped_hours_before_termination.hours.ago - 1.minute
          end

          it_behaves_like 'workspace lifecycle management expectations',
            expected_desired_state: RemoteDevelopment::WorkspaceOperations::States::TERMINATED
        end
      end

      context "when the agent encounters an error while starting the workspace" do
        let(:actual_state) { states_module::STARTING }
        let(:desired_state) { states_module::RUNNING }
        let(:expected_actual_state) { states_module::ERROR }
        let(:expected_config_to_apply_include_all_resources) { true }
        let(:error_from_agent) do
          {
            error_type: RemoteDevelopment::WorkspaceOperations::Reconcile::ErrorType::APPLIER,
            error_message: "some applier error"
          }
        end

        let(:workspace) do
          create(
            :workspace,
            :after_initial_reconciliation,
            **workspace_fixture_common_args
          )
        end

        it 'returns proper workspace_rails_info entry with config to apply' do
          # verify initial states in db (sanity check of match between factory and fixtures)
          expect(workspace.desired_state).to eq(desired_state)
          expect(workspace.actual_state).to eq(actual_state)

          # expect abnormal agent info to be logged at warn level
          expect(logger).to receive(:warn).with(hash_including(error_type: "abnormal_actual_state"))

          expect(response[:message]).to be_nil
          workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
          expect(workspace_rails_infos.length).to eq(1)

          workspace.reload

          expect(workspace.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          # test the config to apply first to get a more specific diff if it fails
          provisioned_workspace_rails_info =
            workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
          # Even though the workspace is now in Error state, we will continue returning the config to the agent
          # if it would have been returned in the normal case, in case the error is transient
          expect(provisioned_workspace_rails_info.fetch(:config_to_apply)).to eq(expected_config_to_apply_yaml_stream)

          # then test everything in the infos
          expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
        end
      end

      context 'when only some workspaces fail in devfile flattener' do
        let(:expected_config_to_apply_yaml_stream) { "" }
        let(:invalid_devfile_yaml) { read_devfile_yaml('example.invalid-extra-field-devfile.yaml.erb') }

        let(:workspace2) do
          create(:workspace, devfile: invalid_devfile_yaml, name: "workspace-failing-flatten",
            agent: agent, user: user, force_include_all_resources: false)
        end

        let(:workspace2_agent_info) do
          create_workspace_agent_info_hash(
            workspace: workspace2,
            previous_actual_state: previous_actual_state,
            current_actual_state: current_actual_state,
            workspace_exists: workspace_exists,
            resource_version: deployment_resource_version_from_agent
          )
        end

        # NOTE: Reverse the order so that the failing one is processed first and ensures that the second valid
        #       one is still processed successfully.
        let(:workspace_agent_infos) { [workspace2_agent_info, workspace_agent_info] }

        let(:expected_workspace2_rails_info) do
          {
            name: workspace2.name,
            namespace: workspace2.namespace,
            desired_state: expected_desired_state,
            actual_state: expected_actual_state,
            deployment_resource_version: expected_deployment_resource_version,
            config_to_apply: "",
            image_pull_secrets: image_pull_secrets
          }
        end

        # NOTE: WorkspacesToBeReturnedFinder sorts by workspace ID, so the first fixture to be created will be first
        let(:expected_workspace_rails_infos) { [expected_workspace_rails_info, expected_workspace2_rails_info] }

        it 'returns proper workspace_rails_info entries' do
          expect(response[:message]).to be_nil
          workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
          expect(workspace_rails_infos.length).to eq(2)

          expect(workspace.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          expect(workspace2.deployment_resource_version)
            .to eq(expected_deployment_resource_version)

          workspace2_rails_info =
            workspace_rails_infos.detect { |info| info.fetch(:name) == workspace2.name }
          expect(workspace2_rails_info.fetch(:config_to_apply)).to eq("")

          # then test everything in the infos
          expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
        end
      end

      context 'with timestamp precondition checks' do
        # rubocop:disable RSpec/ExpectInHook -- We are just confirming fixtures, no need to run these as a full example which would slow down the test, or to duplicate them in each example.
        before do
          # Ensure that both desired_state_updated_at, actual_stated_updated_at, and responded_to_agent_at are
          # before Time.current, so that we can test for any necessary differences after processing updates them
          expect(workspace.desired_state_updated_at).to be_before(Time.current)
          expect(workspace.actual_state_updated_at).to be_before(Time.current)
          expect(workspace.responded_to_agent_at).to be_before(Time.current)
        end

        after do
          # After processing, the responded_to_agent_at should always have been updated
          workspace.reload
          expect(workspace.responded_to_agent_at).not_to be_before(workspace.desired_state_updated_at)
          expect(workspace.responded_to_agent_at).not_to be_before(workspace.actual_state_updated_at)
        end
        # rubocop:enable RSpec/ExpectInHook

        context 'when desired_state matches actual_state' do
          # rubocop:disable RSpec/ExpectInHook -- We are just confirming fixtures, no need to run these as a full example which would slow down the test, or to duplicate them in each example.
          before do
            # confirm fixture values
            expect(workspace.responded_to_agent_at).to be_after(workspace.desired_state_updated_at)
            expect(workspace.responded_to_agent_at).to be_after(workspace.actual_state_updated_at)
          end
          # rubocop:enable RSpec/ExpectInHook

          context 'when state is Stopped' do
            let(:expected_config_to_apply_yaml_stream) { "" }
            let(:desired_state) { states_module::STOPPED }

            it 'updates workspace record and returns proper workspace_rails_info entry' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.desired_state).to eq(workspace.actual_state)
              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when state is Terminated' do
            let(:desired_state) { states_module::TERMINATED }
            let(:previous_actual_state) { states_module::TERMINATED }
            let(:current_actual_state) { states_module::TERMINATED }
            let(:expected_config_to_apply_yaml_stream) { "" }
            let(:expected_deployment_resource_version) { workspace.deployment_resource_version }

            it 'updates workspace record and returns proper workspace_rails_info entry' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              # We could do this with a should_not_change block but this reads cleaner IMO
              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.desired_state).to eq(workspace.actual_state)
              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end
        end

        context 'when desired_state does not match actual_state' do
          let(:deployment_resource_version_from_agent) { workspace.deployment_resource_version }

          # rubocop:disable RSpec/ExpectInHook -- We are just confirming fixtures, no need to run these as a full example which would slow down the test, or to duplicate them in each example.
          before do
            expect(workspace.responded_to_agent_at).to be_before(workspace.desired_state_updated_at)
            expect(workspace.responded_to_agent_at).to be_after(workspace.actual_state_updated_at)
          end
          # rubocop:enable RSpec/ExpectInHook

          context 'when desired_state is Running' do
            let(:desired_state) { states_module::RUNNING }

            it 'returns proper workspace_rails_info entry with config_to_apply' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              # test the config to apply first to get a more specific diff if it fails
              actual_workspace_rails_info = workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              actual_config_to_apply =
                yaml_safe_load_stream_symbolized(actual_workspace_rails_info.fetch(:config_to_apply))
              expected_config_to_apply =
                yaml_safe_load_stream_symbolized(expected_workspace_rails_info.fetch(:config_to_apply))
              expect(actual_config_to_apply).to eq(expected_config_to_apply)

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when desired_state is Terminated' do
            let(:desired_state) { states_module::TERMINATED }
            let(:expected_started) { false }
            let(:expected_desired_state_is_terminated) { true }

            it 'returns proper workspace_rails_info entry with config_to_apply' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload

              expect(workspace.deployment_resource_version)
                .to eq(expected_deployment_resource_version)

              # test the config to apply first to get a more specific diff if it fails
              provisioned_workspace_rails_info =
                workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              actual = provisioned_workspace_rails_info.fetch(:config_to_apply)
              expected = expected_workspace_rails_info.fetch(:config_to_apply)
              expect(actual).to eq(expected)

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when desired_state is RestartRequested and actual_state is Stopped' do
            let(:desired_state) { states_module::RESTART_REQUESTED }
            let(:expected_desired_state) { states_module::RUNNING }

            it 'changes desired_state to Running' do
              # verify initial states in db (sanity check of match between factory and fixtures)
              expect(workspace.desired_state).to eq(desired_state)
              expect(workspace.actual_state).to eq(actual_state)

              expect(response[:message]).to be_nil
              workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
              expect(workspace_rails_infos.length).to eq(1)

              workspace.reload
              expect(workspace.desired_state).to eq(expected_desired_state)

              # test the config to apply first to get a more specific diff if it fails
              provisioned_workspace_rails_info =
                workspace_rails_infos.detect { |info| info.fetch(:name) == workspace.name }
              expect(provisioned_workspace_rails_info[:config_to_apply])
                .to eq(expected_workspace_rails_info.fetch(:config_to_apply))

              # then test everything in the infos
              expect(workspace_rails_infos).to eq(expected_workspace_rails_infos)
            end
          end

          context 'when actual_state is Unknown' do
            let(:current_actual_state) { states_module::UNKNOWN }
            let(:expected_actual_state) { states_module::UNKNOWN }
            let(:expected_started) { false }

            it 'returns the proper response' do
              # expect abnormal agent info to be logged at warn level
              expect(logger).to receive(:warn).with(hash_including(error_type: "abnormal_actual_state"))

              expect(response[:message]).to be_nil

              # Do redundant but progressively higher level checks on the response, so we can have better diffs
              # for debugging if any of the lower-level checks fail.
              config_to_apply_hash = YAML.safe_load(
                response[:payload].fetch(:workspace_rails_infos)[0][:config_to_apply]
              )
              expected_config_to_apply_hash = YAML.safe_load(expected_config_to_apply_yaml_stream)
              expect(config_to_apply_hash).to eq(expected_config_to_apply_hash)

              expect(response[:payload][:workspace_rails_infos][0][:config_to_apply])
                .to eq(expected_config_to_apply_yaml_stream)

              expect(response[:payload][:workspace_rails_infos]).to eq(expected_workspace_rails_infos)
            end
          end
        end
      end
    end

    context 'when receiving agent updates for a workspace which does not exist in the db' do
      let(:nonexistent_workspace) do
        instance_double(
          "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          id: 1, name: 'x', namespace: 'x', agent: agent
        )
      end

      let(:workspace_agent_info) do
        create_workspace_agent_info_hash(
          workspace: nonexistent_workspace,
          previous_actual_state: states_module::STOPPING,
          current_actual_state: states_module::STOPPED,
          workspace_exists: false,
          workspace_variables_environment: {},
          workspace_variables_file: {},
          workspace_variables_additional_data: {}
        )
      end

      let(:workspace_agent_infos) { [workspace_agent_info] }

      let(:expected_workspace_rails_infos) { [] }

      it 'logs orphaned workspace and does not attempt to update the workspace in the db' do
        expect(logger).to receive(:warn).with(hash_including(error_type: "orphaned_workspace"))

        expect(response[:message]).to be_nil
        workspace_rails_infos = response.fetch(:payload).fetch(:workspace_rails_infos)
        expect(workspace_rails_infos).to be_empty
      end

      it 'returns settings' do
        expect(logger).to receive(:warn).with(hash_including(error_type: "orphaned_workspace"))

        settings = response.fetch(:payload).fetch(:settings)
        expect(settings[:full_reconciliation_interval_seconds]).not_to be_nil
      end
    end

    context 'when new unprovisioned workspace exists in database"' do
      include_context "with unprovisioned workspace"

      it_behaves_like "unprovisioned workspace expectations"
      it_behaves_like 'includes settings in payload'
      it_behaves_like 'versioned workspaces_agent_configs behavior'
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
