# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::RolloutStep, feature_category: :continuous_delivery do
  let_it_be(:rollout) { create(:cd_rollout) }
  let_it_be(:rollout_environment) { create(:cd_rollout_environment, rollout: rollout) }

  describe 'factory' do
    it 'creates a valid rollout step using factory defaults' do
      expect(create(:cd_rollout_step)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:rollout).required }
    it { is_expected.to belong_to(:rollout_environment).optional }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'enums' do
    it 'defines state' do
      is_expected.to define_enum_for(:state).with_values(
        pending: 0,
        running: 1,
        awaiting_approval: 2,
        approved: 3,
        rejected: 4,
        success: 5,
        failed: 6,
        skipped: 7,
        cancelled: 8
      )
    end
  end

  describe 'validations' do
    subject { build(:cd_rollout_step, rollout: rollout) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:path) }
    it { is_expected.to validate_length_of(:path).is_at_most(255) }
    it { is_expected.to validate_length_of(:parent_path).is_at_most(255) }
    it { is_expected.to validate_presence_of(:step_type) }
    it { is_expected.to validate_length_of(:step_type).is_at_most(255) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:error).is_at_most(2000) }

    it 'validates uniqueness of path scoped to rollout' do
      create(:cd_rollout_step, rollout: rollout, path: '0')

      expect(build(:cd_rollout_step, rollout: rollout, path: '0')).not_to be_valid
    end

    it 'allows the same path across different rollouts' do
      other_rollout = create(:cd_rollout)
      create(:cd_rollout_step, rollout: rollout, path: '0')

      expect(build(:cd_rollout_step, rollout: other_rollout, path: '0')).to be_valid
    end

    describe 'params' do
      it 'accepts a Hash' do
        expect(build(:cd_rollout_step, rollout: rollout, params: { 'seconds' => 30 })).to be_valid
      end

      it 'accepts nil' do
        expect(build(:cd_rollout_step, rollout: rollout, params: nil)).to be_valid
      end

      it 'rejects a non-object value' do
        expect(build(:cd_rollout_step, rollout: rollout, params: [1, 2])).not_to be_valid
      end
    end
  end

  describe 'state machine' do
    subject(:step) { build(:cd_rollout_step, rollout: rollout) }

    it 'has an initial state of pending' do
      expect(step).to be_pending
    end

    it 'declares every state used by either lifecycle' do
      is_expected.to have_states(
        :pending, :running, :awaiting_approval, :approved, :rejected, :success, :failed, :skipped, :cancelled
      )
    end

    context 'for an ordinary step, which runs rather than waiting on a human' do
      subject(:step) { build(:cd_rollout_step, rollout: rollout, step_type: 'com.gitlab.cd.argo.canary.deploy') }

      it { is_expected.to handle_events(:start, when: :pending) }
      it { is_expected.to reject_events(:approve, :reject, when: :pending) }

      it { is_expected.to handle_events(:succeed, :fail_step, :skip, :cancel, when: :running) }
      it { is_expected.to reject_events(:start, :approve, :reject, when: :running) }

      it 'is terminal' do
        is_expected.to reject_events(:start, :succeed, :fail_step, :approve, :reject, :skip, :cancel, when: :success)
      end
    end

    context 'for an approval step, which waits on a human instead of running' do
      subject(:step) { build(:cd_rollout_step, rollout: rollout, step_type: Cd::RolloutStep::APPROVAL_STEP_TYPE) }

      it { is_expected.to handle_events(:start, when: :pending) }
      it { is_expected.to reject_events(:succeed, :fail_step, when: :pending) }

      it { is_expected.to handle_events(:approve, :reject, :skip, :cancel, when: :awaiting_approval) }
      it { is_expected.to reject_events(:start, :succeed, :fail_step, when: :awaiting_approval) }
    end

    describe 'callbacks' do
      describe 'triggering cd_rollout_step_updated' do
        it 'fires the subscription trigger after commit on any transition' do
          expect(GraphqlTriggers).to receive(:cd_rollout_step_updated).with(step)

          step.start!
        end

        it 'does not fire the subscription trigger when the transaction is rolled back' do
          expect(GraphqlTriggers).not_to receive(:cd_rollout_step_updated)

          Cd::RolloutStep.transaction do
            step.start!
            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end

  describe 'sharding key' do
    subject { build(:cd_rollout_step, rollout: rollout) }

    it { is_expected.to populate_sharding_key(:organization_id).with(rollout.organization_id) }
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'returns rollout steps in creation order' do
        first = create(:cd_rollout_step, rollout: rollout, path: '1')
        second = create(:cd_rollout_step, rollout: rollout, path: '0')

        expect(described_class.ordered).to eq([first, second])
      end
    end
  end

  it 'can be linked to a rollout environment for drill-down' do
    step = create(:cd_rollout_step, rollout: rollout, rollout_environment: rollout_environment,
      step_type: 'com.gitlab.cd.argo.canary.deploy')

    expect(step.rollout_environment).to eq(rollout_environment)
  end
end
