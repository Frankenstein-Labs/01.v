# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::RolloutTransition, feature_category: :continuous_delivery do
  let_it_be(:rollout) { create(:cd_rollout) }

  describe 'factory' do
    it 'creates a valid rollout transition using factory defaults' do
      expect(create(:cd_rollout_transition)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:rollout).required }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'enums' do
    it 'defines from_state enum with a prefix' do
      is_expected.to define_enum_for(:from_state)
        .with_values(initial: 0, pending: 1, in_progress: 2, paused: 3, completed: 4, failed: 5, cancelled: 6)
        .with_prefix(:from)
    end

    it 'defines to_state enum with a prefix' do
      is_expected.to define_enum_for(:to_state)
        .with_values(initial: 0, pending: 1, in_progress: 2, paused: 3, completed: 4, failed: 5, cancelled: 6)
        .with_prefix(:to)
    end
  end

  describe 'validations' do
    subject { build(:cd_rollout_transition, rollout: rollout) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:event) }
    it { is_expected.to validate_length_of(:event).is_at_most(72) }
    it { is_expected.to validate_presence_of(:from_state) }
    it { is_expected.to validate_presence_of(:to_state) }
    it { is_expected.to validate_presence_of(:principal) }
    it { is_expected.to validate_length_of(:principal).is_at_most(255) }
    it { is_expected.to validate_length_of(:on_behalf_of).is_at_most(255) }
    it { is_expected.to validate_length_of(:reason).is_at_most(2000) }
    it { is_expected.to validate_length_of(:triggered_by).is_at_most(255) }
  end

  describe 'append-only' do
    it 'is readonly once persisted' do
      transition = create(:cd_rollout_transition, rollout: rollout)

      expect { transition.update!(reason: 'changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'returns transitions ordered by created_at ascending' do
        # Created newest-first so the assertion proves the scope reorders them.
        newer = create(:cd_rollout_transition, rollout: rollout, created_at: 1.day.ago)
        older = create(:cd_rollout_transition, rollout: rollout, created_at: 2.days.ago)

        expect(described_class.ordered).to eq([older, newer])
      end
    end

    describe '.gate_events' do
      it 'returns only request_approval/approve/reject transitions' do
        gate_transition = create(:cd_rollout_transition, rollout: rollout, event: 'request_approval')
        create(:cd_rollout_transition, rollout: rollout, event: 'start')

        expect(described_class.gate_events).to contain_exactly(gate_transition)
      end
    end
  end

  describe 'sharding key' do
    subject { build(:cd_rollout_transition, rollout: rollout) }

    it { is_expected.to populate_sharding_key(:organization_id).with(rollout.organization_id) }
  end

  describe '#acting_user_id' do
    it 'returns the user id parsed from principal' do
      transition = build(:cd_rollout_transition, rollout: rollout, principal: 'user:42')

      expect(transition.acting_user_id).to eq(42)
    end

    it 'prefers on_behalf_of over principal when both are present' do
      transition = build(:cd_rollout_transition,
        rollout: rollout, principal: 'agent:autoflow', on_behalf_of: 'user:7')

      expect(transition.acting_user_id).to eq(7)
    end

    it 'returns nil for a non-user principal' do
      transition = build(:cd_rollout_transition, rollout: rollout, principal: 'system:autoflow')

      expect(transition.acting_user_id).to be_nil
    end

    it 'returns nil when neither principal nor on_behalf_of resolve to a user' do
      transition = build(:cd_rollout_transition,
        rollout: rollout, principal: 'policy:auto-rollback', on_behalf_of: 'agent:autoflow')

      expect(transition.acting_user_id).to be_nil
    end
  end

  describe '#principal_user_id' do
    it 'returns the user id parsed from principal' do
      transition = build(:cd_rollout_transition, rollout: rollout, principal: 'user:42')

      expect(transition.principal_user_id).to eq(42)
    end

    it 'ignores on_behalf_of' do
      transition = build(:cd_rollout_transition,
        rollout: rollout, principal: 'agent:autoflow', on_behalf_of: 'user:7')

      expect(transition.principal_user_id).to be_nil
    end

    it 'returns nil for a non-user principal' do
      transition = build(:cd_rollout_transition, rollout: rollout, principal: 'system:autoflow')

      expect(transition.principal_user_id).to be_nil
    end
  end

  describe '.open_gate_rollout_ids' do
    it 'returns the ids of rollouts whose latest gate event is an unresolved request_approval' do
      open_rollout = create(:cd_rollout)
      resolved_rollout = create(:cd_rollout)
      never_gated_rollout = create(:cd_rollout)

      create(:cd_rollout_transition, rollout: open_rollout, event: 'request_approval', created_at: 1.hour.ago)

      create(:cd_rollout_transition, rollout: resolved_rollout, event: 'request_approval', created_at: 2.hours.ago)
      create(:cd_rollout_transition, rollout: resolved_rollout, event: 'approve', created_at: 1.hour.ago)

      create(:cd_rollout_transition, rollout: never_gated_rollout, event: 'start')

      result = described_class.open_gate_rollout_ids([open_rollout.id, resolved_rollout.id, never_gated_rollout.id])

      expect(result).to contain_exactly(open_rollout.id)
    end

    using RSpec::Parameterized::TableSyntax

    where(:resolving_event) { %w[approve reject] }

    with_them do
      it 'excludes a rollout once its gate has been resolved' do
        resolved_rollout = create(:cd_rollout)

        create(:cd_rollout_transition, rollout: resolved_rollout, event: 'request_approval', created_at: 1.hour.ago)
        create(:cd_rollout_transition, rollout: resolved_rollout, event: resolving_event)

        expect(described_class.open_gate_rollout_ids([resolved_rollout.id])).to be_empty
      end
    end

    it 'ignores non-gate events that happen after the latest gate event' do
      rollout_with_later_non_gate_event = create(:cd_rollout)

      create(:cd_rollout_transition,
        rollout: rollout_with_later_non_gate_event, event: 'request_approval', created_at: 2.hours.ago)
      create(:cd_rollout_transition, rollout: rollout_with_later_non_gate_event, event: 'start', created_at: 1.hour.ago)

      result = described_class.open_gate_rollout_ids([rollout_with_later_non_gate_event.id])

      expect(result).to contain_exactly(rollout_with_later_non_gate_event.id)
    end
  end

  describe '.first_acting_user_id_by_rollout' do
    it 'returns the acting user id of the earliest transition, keyed by rollout id' do
      other_rollout = create(:cd_rollout)

      create(:cd_rollout_transition, rollout: rollout, principal: 'user:1', created_at: 2.days.ago)
      create(:cd_rollout_transition, rollout: rollout, principal: 'user:2', created_at: 1.day.ago)
      create(:cd_rollout_transition, rollout: other_rollout, principal: 'user:3')

      result = described_class.first_acting_user_id_by_rollout([rollout.id, other_rollout.id])

      expect(result).to eq(rollout.id => 1, other_rollout.id => 3)
    end

    it 'omits rollouts whose earliest transition has no resolvable user' do
      create(:cd_rollout_transition, rollout: rollout, principal: 'system:autoflow')

      expect(described_class.first_acting_user_id_by_rollout([rollout.id])).to eq({})
    end

    it 'returns an empty hash for rollouts with no transitions' do
      expect(described_class.first_acting_user_id_by_rollout([rollout.id])).to eq({})
    end
  end
end
