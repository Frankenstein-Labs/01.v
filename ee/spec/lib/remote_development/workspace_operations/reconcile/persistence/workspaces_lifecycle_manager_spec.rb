# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesLifecycleManager, feature_category: :workspaces do
  include_context "with constant modules"

  let(:year) { 2021 }

  let!(:now) do
    Time.utc(year, 1, 1)
  end

  let(:max_hours_before_termination) do
    RemoteDevelopment::WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION
  end

  let(:max_active_hours_before_stop) { RemoteDevelopment::Settings.get_single_setting(:max_active_hours_before_stop) }
  let(:max_stopped_hours_before_termination) do
    RemoteDevelopment::Settings.get_single_setting(:max_stopped_hours_before_termination)
  end

  let(:max_allowable_workspace_age) { now - max_hours_before_termination.hours }

  let(:running) { states_module::RUNNING }
  let(:stopped) { states_module::STOPPED }
  let(:terminated) { states_module::TERMINATED }

  let(:workspaces_from_agent_infos) { [workspace] }

  let(:context) do
    {
      workspaces_from_agent_infos: workspaces_from_agent_infos
    }
  end

  subject(:returned_value) do
    described_class.manage(context)
  end

  after do
    travel_back

    # Be super-sure we aren't introducing a leaky test to break the build!
    raise "Time was not correctly unfrozen/unstubbed!" if Time.zone.now.year == year
  end

  context 'with various workspace states and conditions' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- We don't want to wrap RSpec::Parameterized::TableSyntax, it hurts readability
    where(:scenario, :created_at, :desired_state_updated_at, :initial_desired_state, :expected_desired_state) do
      "No limits exceeded, workspace just created, expect no state change" | now | now | running | running
      "No limits exceeded, workspace is at max allowable active hours, no state change" | (now - max_active_hours_before_stop.hours + 1) | (now - max_active_hours_before_stop.hours + 1) | running | running
      "No limits exceeded, workspace is at max allowable age, desired_state just updated, expect no state change" | max_allowable_workspace_age | now | running | running
      "max_hours_before_termination limit exceeded, not already terminated, expect state to change to terminated" | (max_allowable_workspace_age - 1) | now | running | terminated
      "max_hours_before_termination limit exceeded, already terminated, expect no state change" | (max_allowable_workspace_age - 1) | now | terminated | terminated
      "max_active_hours_before_stop limit exceeded, not already stopped, expect state to change to stopped" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | running | stopped
      "max_active_hours_before_stop limit exceeded, already stopped, expect no state change" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | stopped | stopped
      "max_active_hours_before_stop limit exceeded, already terminated, expect no state change" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | terminated | terminated
      "max_stopped_hours_before_termination limit exceeded, not already terminated, expect state to change to terminated" | max_allowable_workspace_age | (now - max_stopped_hours_before_termination.hours - 1) | stopped | terminated
      "max_stopped_hours_before_termination limit exceeded, already terminated, expect no state change" | max_allowable_workspace_age | (now - max_stopped_hours_before_termination.hours - 1) | terminated | terminated
    end
    # rubocop:enable Layout/LineLength -- We don't want to wrap RSpec::Parameterized::TableSyntax, it hurts readability

    with_them do
      let(:workspaces_agent_config) do
        instance_double(
          "RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          max_active_hours_before_stop: max_active_hours_before_stop,
          max_stopped_hours_before_termination: max_stopped_hours_before_termination
        )
      end

      let(:workspace) do
        instance_double(
          "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          created_at: created_at,
          desired_state_updated_at: desired_state_updated_at,
          desired_state: initial_desired_state,
          desired_state_stopped?: initial_desired_state == states_module::STOPPED,
          workspaces_agent_config: workspaces_agent_config
        )
      end

      it "correctly updates (or not) desired_state" do
        travel_to(now)
        # "now" time fixture validity check - ensure that time is properly frozen
        expect(Time.zone.now.to_i).to eq(Time.utc(2021, 1, 1).to_i)

        if expected_desired_state == initial_desired_state
          expect(workspace).not_to receive(:update!)
        else
          expect(workspace).to receive(:update!).with(desired_state: expected_desired_state).once
        end

        expect(returned_value).to eq(context)
      end
    end
  end

  it 'does not leak the time' do
    # Be super-sure we aren't introducing a leaky test to break the build!
    expect(Time.zone.now.to_i).to be > now.to_i
  end
end
