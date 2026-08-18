# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollout, feature_category: :continuous_delivery do
  let_it_be(:version_set) { create(:cd_version_set) }

  describe 'factory' do
    it 'creates a valid rollout using factory defaults' do
      expect(create(:cd_rollout)).to be_valid
    end
  end

  describe 'iid' do
    let_it_be(:application) { create(:cd_application) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }

    it 'assigns a per-application iid starting at 1' do
      expect(create(:cd_rollout, version_set: version_set, state: :cancelled).iid).to eq(1)
    end

    it 'increments the iid for each new rollout in the application' do
      first = create(:cd_rollout, version_set: version_set, state: :cancelled)
      second = create(:cd_rollout, version_set: version_set, state: :cancelled)

      expect([first.iid, second.iid]).to eq([1, 2])
    end

    it 'numbers each application independently' do
      create(:cd_rollout, version_set: version_set, state: :cancelled)
      other = create(:cd_rollout, state: :cancelled)

      expect(other.iid).to eq(1)
    end

    it 'keeps an explicitly provided iid' do
      expect(create(:cd_rollout, version_set: version_set, state: :cancelled, iid: 99).iid).to eq(99)
    end
  end

  describe '.search_by_iid' do
    let_it_be(:rollout) { create(:cd_rollout, state: :cancelled, iid: 42) }

    it 'matches an exact iid' do
      expect(described_class.search_by_iid('42')).to contain_exactly(rollout)
    end

    it 'tolerates a leading "#"' do
      expect(described_class.search_by_iid('#42')).to contain_exactly(rollout)
    end

    it 'returns nothing when no rollout matches' do
      expect(described_class.search_by_iid('999')).to be_empty
    end

    it 'returns nothing for a non-numeric term' do
      expect(described_class.search_by_iid('nope')).to be_empty
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:version_set).required }
    it { is_expected.to belong_to(:application).required }
    it { is_expected.to belong_to(:application_flow_definition).optional }
    it { is_expected.to have_many(:rollout_environments) }
    it { is_expected.to have_many(:rollout_transitions) }

    it 'orders rollout_environments by position ascending' do
      rollout = create(:cd_rollout)
      # Created out of position order so the assertion proves the association reorders them.
      second = create(:cd_rollout_environment, rollout: rollout, position: 2)
      first = create(:cd_rollout_environment, rollout: rollout, position: 1)

      expect(rollout.rollout_environments).to eq([first, second])
    end

    it 'orders rollout_transitions by created_at ascending' do
      rollout = create(:cd_rollout)
      newer = create(:cd_rollout_transition, rollout: rollout, created_at: 1.day.ago)
      older = create(:cd_rollout_transition, rollout: rollout, created_at: 2.days.ago)

      expect(rollout.rollout_transitions).to eq([older, newer])
    end
  end

  describe 'validations' do
    subject { build(:cd_rollout, version_set: version_set) }

    it { is_expected.to validate_length_of(:workflow_ref).is_at_most(255) }

    describe 'workflow_ref presence' do
      it 'is valid without a workflow_ref while pending' do
        expect(build(:cd_rollout, version_set: version_set, state: :pending, workflow_ref: nil)).to be_valid
      end

      %i[in_progress paused completed failed].each do |state|
        it "requires a workflow_ref when #{state}" do
          rollout = build(:cd_rollout, version_set: version_set, state: state, workflow_ref: nil)

          expect(rollout).not_to be_valid
          expect(rollout.errors[:workflow_ref]).to include("can't be blank")
        end

        it "is valid with a workflow_ref when #{state}" do
          expect(build(:cd_rollout, version_set: version_set, state: state, workflow_ref: 'wk:1/abc')).to be_valid
        end
      end

      # `cancelled` has different semantics from the other non-pending states: it is
      # reachable directly from `pending` (see `cancel` event), so a `workflow_ref`
      # is only guaranteed once the rollout has actually started (`started_at` set).
      describe 'when cancelled' do
        it "is valid with a workflow_ref" do
          expect(
            build(:cd_rollout, version_set: version_set, state: :cancelled, workflow_ref: 'wk:1/abc')
          ).to be_valid
        end

        context 'when the rollout had already started' do
          it 'requires a workflow_ref' do
            rollout = build(
              :cd_rollout, version_set: version_set, state: :cancelled, started_at: 1.hour.ago, workflow_ref: nil
            )

            expect(rollout).not_to be_valid
            expect(rollout.errors[:workflow_ref]).to include("can't be blank")
          end
        end

        context 'when the rollout was cancelled directly from pending (never started)' do
          it 'is valid without a workflow_ref' do
            rollout = build(
              :cd_rollout, version_set: version_set, state: :cancelled, started_at: nil, workflow_ref: nil
            )

            expect(rollout).to be_valid
          end
        end
      end
    end
  end

  describe 'enums' do
    it 'defines state enum' do
      is_expected.to define_enum_for(:state).with_values(
        pending: 0,
        in_progress: 1,
        paused: 2,
        completed: 3,
        failed: 4,
        cancelled: 5
      )
    end
  end

  describe 'sharding key' do
    subject { build(:cd_rollout, version_set: version_set) }

    it { is_expected.to populate_sharding_key(:organization_id).with(version_set.organization_id) }
  end

  describe '.for_statuses' do
    # Each non-terminal (pending/in_progress/paused) rollout needs its own
    # application to satisfy the one-active-rollout-per-application partial
    # unique index, so every fixture here gets a fresh application.
    let_it_be(:pending_rollout) { create(:cd_rollout, version_set: create(:cd_version_set), state: :pending) }
    let_it_be(:in_progress_rollout) do
      create(:cd_rollout, version_set: create(:cd_version_set), state: :in_progress, workflow_ref: 'wk:1/abc')
    end

    let_it_be(:paused_rollout) do
      create(:cd_rollout, version_set: create(:cd_version_set), state: :paused, workflow_ref: 'wk:1/abc')
    end

    let_it_be(:completed_rollout) do
      create(:cd_rollout, version_set: create(:cd_version_set), state: :completed, workflow_ref: 'wk:1/abc')
    end

    let_it_be(:failed_rollout) do
      create(:cd_rollout, version_set: create(:cd_version_set), state: :failed, workflow_ref: 'wk:1/abc')
    end

    let_it_be(:cancelled_rollout) do
      create(:cd_rollout, version_set: create(:cd_version_set), state: :cancelled, workflow_ref: 'wk:1/abc')
    end

    it 'returns pending, in_progress, and paused rollouts for the active status' do
      expect(described_class.for_statuses(%w[active])).to contain_exactly(
        pending_rollout, in_progress_rollout, paused_rollout
      )
    end

    it 'returns only completed rollouts for the succeeded status' do
      expect(described_class.for_statuses(%w[succeeded])).to contain_exactly(completed_rollout)
    end

    it 'returns failed and cancelled rollouts for the failed status' do
      expect(described_class.for_statuses(%w[failed])).to contain_exactly(failed_rollout, cancelled_rollout)
    end

    it 'returns the union of rollouts when multiple statuses are given' do
      expect(described_class.for_statuses(%w[succeeded failed])).to contain_exactly(
        completed_rollout, failed_rollout, cancelled_rollout
      )
    end

    it 'ignores unknown statuses instead of matching on a null state' do
      expect(described_class.for_statuses(%w[bogus])).to be_empty
    end

    it 'does not let an unknown status affect matching on other given statuses' do
      expect(described_class.for_statuses(%w[succeeded bogus])).to contain_exactly(completed_rollout)
    end

    it 'does not query for a null state when given an unknown status' do
      expect(described_class.for_statuses(%w[bogus]).to_sql).not_to include('IS NULL')
    end
  end

  describe '#sync_state_from_steps!' do
    let_it_be_with_reload(:rollout) do
      create(:cd_rollout, version_set: version_set, state: :in_progress, workflow_ref: 'wk:1/abc')
    end

    it 'does nothing when the rollout is not in_progress' do
      rollout.update_column(:state, described_class.states['paused'])
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :failed)

      expect { rollout.sync_state_from_steps! }.not_to change { rollout.reload.state }
    end

    it 'does nothing while any top-level step is still unfinished' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :success)
      create(:cd_rollout_step, rollout: rollout, path: '1', state: :running)

      expect { rollout.sync_state_from_steps! }.not_to change { rollout.reload.state }
    end

    it 'does nothing when the rollout has no steps yet' do
      expect { rollout.sync_state_from_steps! }.not_to change { rollout.reload.state }
    end

    it 'completes the rollout once every top-level step has succeeded or been skipped' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :success)
      create(:cd_rollout_step, rollout: rollout, path: '1', state: :skipped)

      expect { rollout.sync_state_from_steps! }
        .to change { rollout.reload.state }.from('in_progress').to('completed')
    end

    it 'fails the rollout as soon as any top-level step fails, even with steps still pending' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :failed)
      create(:cd_rollout_step, rollout: rollout, path: '1', state: :pending)

      expect { rollout.sync_state_from_steps! }
        .to change { rollout.reload.state }.from('in_progress').to('failed')
    end

    it 'fails the rollout when a nested step fails, even if its stage step never started' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :pending)
      create(:cd_rollout_step, rollout: rollout, path: '0.0', parent_path: '0', state: :failed)

      expect { rollout.sync_state_from_steps! }
        .to change { rollout.reload.state }.from('in_progress').to('failed')
    end

    it 'treats a rejected approval step the same as a failure' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :rejected)

      expect { rollout.sync_state_from_steps! }
        .to change { rollout.reload.state }.from('in_progress').to('failed')
    end

    it 'does not complete a rollout with a cancelled step, even when the rest succeeded' do
      create(:cd_rollout_step, rollout: rollout, path: '0', state: :success)
      create(:cd_rollout_step, rollout: rollout, path: '1', state: :cancelled)

      expect { rollout.sync_state_from_steps! }
        .to change { rollout.reload.state }.from('in_progress').to('failed')
    end
  end

  describe 'defaults' do
    it 'defaults state to pending' do
      record = described_class.new

      expect(record.state).to eq('pending')
    end
  end

  describe 'state machine' do
    # A rollout being transitioned has already been kicked off, so it carries a
    # workflow_ref (required in every non-pending state).
    subject(:rollout) { create(:cd_rollout, version_set: version_set, workflow_ref: 'wk:1/abc') }

    it 'has an initial state of pending' do
      expect(rollout).to be_pending
    end

    describe 'states' do
      it 'declares all expected states' do
        is_expected.to have_states(
          :pending, :in_progress, :paused,
          :completed, :failed, :cancelled
        )
      end
    end

    describe 'event handling' do
      it { is_expected.to handle_events(:start, when: :pending) }
      it { is_expected.to reject_events(:start, when: :in_progress) }
      it { is_expected.to reject_events(:start, when: :completed) }

      it { is_expected.to handle_events(:pause, when: :in_progress) }
      it { is_expected.to reject_events(:pause, when: :pending) }
      it { is_expected.to reject_events(:pause, when: :paused) }

      it { is_expected.to handle_events(:resume, when: :paused) }
      it { is_expected.to reject_events(:resume, when: :in_progress) }
      it { is_expected.to reject_events(:resume, when: :pending) }

      it { is_expected.to handle_events(:complete, when: :in_progress) }
      it { is_expected.to reject_events(:complete, when: :pending) }
      it { is_expected.to reject_events(:complete, when: :failed) }

      it { is_expected.to handle_events(:fail_rollout, when: :in_progress) }
      it { is_expected.to reject_events(:fail_rollout, when: :pending) }
      it { is_expected.to reject_events(:fail_rollout, when: :failed) }

      it { is_expected.to handle_events(:cancel, when: :pending) }
      it { is_expected.to handle_events(:cancel, when: :in_progress) }
      it { is_expected.to handle_events(:cancel, when: :paused) }
      it { is_expected.to reject_events(:cancel, when: :completed) }
      it { is_expected.to reject_events(:cancel, when: :failed) }
      it { is_expected.to reject_events(:cancel, when: :cancelled) }
    end

    describe 'cancelling a rollout that was never started' do
      it 'succeeds without a workflow_ref' do
        pending_rollout = create(:cd_rollout, version_set: version_set, workflow_ref: nil)

        expect { pending_rollout.cancel! }.not_to raise_error
        expect(pending_rollout).to be_cancelled
      end
    end

    describe 'transitions' do
      using RSpec::Parameterized::TableSyntax

      where(:event, :from_state, :to_state) do
        :start         | :pending     | :in_progress
        :pause         | :in_progress | :paused
        :resume        | :paused      | :in_progress
        :complete      | :in_progress | :completed
        :fail_rollout  | :in_progress | :failed
        :cancel        | :pending     | :cancelled
        :cancel        | :in_progress | :cancelled
        :cancel        | :paused      | :cancelled
      end

      with_them do
        before do
          rollout.update_column(:state, described_class.states[from_state.to_s])
        end

        it "transitions from #{params[:from_state]} to #{params[:to_state]} on #{params[:event]}" do
          expect { rollout.public_send(:"#{event}!") }
            .to change { rollout.state }
            .from(from_state.to_s)
            .to(to_state.to_s)
        end
      end
    end

    describe 'callbacks' do
      describe 'setting started_at' do
        context 'when transitioning to in_progress for the first time' do
          it 'sets started_at' do
            freeze_time do
              rollout.start!

              expect(rollout.started_at).to be_like_time(Time.current)
            end
          end
        end

        context 'when resuming from paused' do
          before do
            rollout.update_columns(state: described_class.states['paused'], started_at: 1.hour.ago)
          end

          it 'does not overwrite started_at' do
            original_started_at = rollout.started_at

            rollout.resume!

            expect(rollout.started_at).to be_like_time(original_started_at)
          end
        end
      end

      describe 'setting finished_at' do
        it 'sets finished_at when entering a terminal state', :aggregate_failures do
          terminal_transitions = [
            { from: :in_progress, event: :complete, to: :completed },
            { from: :in_progress, event: :fail_rollout, to: :failed },
            { from: :pending, event: :cancel, to: :cancelled },
            { from: :in_progress, event: :cancel, to: :cancelled },
            { from: :paused, event: :cancel, to: :cancelled }
          ]

          terminal_transitions.each do |transition|
            # Each rollout needs its own application to satisfy the
            # one-active-rollout-per-application partial unique index.
            rollout = create(:cd_rollout, version_set: create(:cd_version_set), workflow_ref: 'wk:1/abc')
            rollout.update_column(:state, described_class.states[transition[:from].to_s])

            freeze_time do
              rollout.public_send(:"#{transition[:event]}!")

              expect(rollout.finished_at).to be_like_time(Time.current),
                "expected finished_at to be set when transitioning " \
                  "from #{transition[:from]} to #{transition[:to]} via #{transition[:event]}"
            end
          end
        end

        it 'does not set finished_at on non-terminal transitions', :aggregate_failures do
          non_terminal_transitions = [
            { from: :pending, event: :start, to: :in_progress },
            { from: :in_progress, event: :pause, to: :paused },
            { from: :paused, event: :resume, to: :in_progress }
          ]

          non_terminal_transitions.each do |transition|
            # Each rollout needs its own application to satisfy the
            # one-active-rollout-per-application partial unique index.
            rollout = create(:cd_rollout, version_set: create(:cd_version_set), workflow_ref: 'wk:1/abc')
            rollout.update_column(:state, described_class.states[transition[:from].to_s])

            rollout.public_send(:"#{transition[:event]}!")

            expect(rollout.finished_at).to be_nil,
              "expected finished_at to remain nil when transitioning " \
                "from #{transition[:from]} to #{transition[:to]} via #{transition[:event]}"
          end
        end
      end

      describe 'triggering cd_rollout_updated' do
        context 'when starting' do
          it 'fires the subscription trigger with a nil reason after commit' do
            expect(GraphqlTriggers).to receive(:cd_rollout_updated).with(rollout, nil)

            rollout.start!
          end
        end

        context 'when the transaction is rolled back' do
          it 'does not fire the subscription trigger' do
            expect(GraphqlTriggers).not_to receive(:cd_rollout_updated)

            Cd::Rollout.transaction do
              rollout.start!
              raise ActiveRecord::Rollback
            end
          end
        end

        context 'on transitions other than starting' do
          it 'does not fire the subscription trigger' do
            expect(GraphqlTriggers).not_to receive(:cd_rollout_updated)

            rollout.update_column(:state, described_class.states['in_progress'])
            rollout.pause!
          end
        end
      end
    end
  end

  describe '#open_approval_gate?' do
    let_it_be(:rollout) { create(:cd_rollout) }

    it 'is false when there are no transitions' do
      expect(rollout.open_approval_gate?).to be(false)
    end

    it 'is true when the latest gate event is an unresolved request_approval' do
      create(:cd_rollout_transition, rollout: rollout, event: 'request_approval')

      expect(rollout.open_approval_gate?).to be(true)
    end

    it 'is false once the gate has been resolved' do
      create(:cd_rollout_transition, rollout: rollout, event: 'request_approval', created_at: 1.hour.ago)
      create(:cd_rollout_transition, rollout: rollout, event: 'approve')

      expect(rollout.open_approval_gate?).to be(false)
    end

    it 'breaks a created_at tie on id, deterministically preferring the later-inserted gate event' do
      timestamp = Time.current
      create(:cd_rollout_transition, rollout: rollout, event: 'request_approval', created_at: timestamp)
      approve = create(:cd_rollout_transition, rollout: rollout, event: 'approve', created_at: timestamp)

      expect(approve.id).to be > rollout.rollout_transitions.gate_events.find_by(event: 'request_approval').id
      expect(rollout.open_approval_gate?).to be(false)
    end
  end
end
