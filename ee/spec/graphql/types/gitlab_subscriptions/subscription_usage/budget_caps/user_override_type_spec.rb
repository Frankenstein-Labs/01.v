# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionBudgetCapUserOverride'],
  feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let(:override_struct) do
    GitlabSubscriptions::SubscriptionsUsage::BudgetCaps::UserOverride
  end

  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionBudgetCapUserOverride') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :user,
      :cap,
      :cap_enabled,
      :created_at,
      :updated_at
    ])
  end

  describe '#user' do
    let_it_be(:user) { create(:user) }

    let(:object) do
      override_struct.new(entity_id: user.id.to_s, cap: 100.0, cap_enabled: true)
    end

    let(:override_type) { described_class.send(:new, object, {}) }

    it 'resolves entity_id to a User via BatchLoader' do
      result = batch_sync { override_type.user }

      expect(result).to eq(user)
    end

    context 'when entity_id is nil' do
      let(:object) do
        override_struct.new(entity_id: nil, cap: 100.0, cap_enabled: true)
      end

      it 'returns nil' do
        expect(override_type.user).to be_nil
      end
    end

    context 'when entity_id references a non-existent user' do
      let(:object) do
        override_struct.new(entity_id: '0', cap: 100.0, cap_enabled: true)
      end

      it 'returns nil' do
        result = batch_sync { override_type.user }

        expect(result).to be_nil
      end
    end
  end

  describe '#created_at' do
    let(:override_type) { described_class.send(:new, object, {}) }

    context 'with a valid timestamp' do
      let(:object) do
        override_struct.new(
          created_at: '2026-04-01T12:00:00Z', cap: 100.0, cap_enabled: true
        )
      end

      it 'parses the timestamp' do
        expect(override_type.created_at).to eq(Time.zone.parse('2026-04-01T12:00:00Z'))
      end
    end

    context 'with nil' do
      let(:object) do
        override_struct.new(created_at: nil, cap: 100.0, cap_enabled: true)
      end

      it 'returns nil' do
        expect(override_type.created_at).to be_nil
      end
    end

    context 'with an unparseable string' do
      let(:object) do
        override_struct.new(created_at: 'not-a-date', cap: 100.0, cap_enabled: true)
      end

      it 'returns nil' do
        expect(override_type.created_at).to be_nil
      end
    end

    context 'with an out-of-range timestamp' do
      let(:object) do
        override_struct.new(
          created_at: '2026-13-01T00:00:00Z', cap: 100.0, cap_enabled: true
        )
      end

      it 'returns nil instead of raising' do
        expect(override_type.created_at).to be_nil
      end
    end
  end

  describe '#updated_at' do
    let(:override_type) { described_class.send(:new, object, {}) }

    context 'with a valid timestamp' do
      let(:object) do
        override_struct.new(
          updated_at: '2026-04-02T08:30:00Z', cap: 100.0, cap_enabled: true
        )
      end

      it 'parses the timestamp' do
        expect(override_type.updated_at).to eq(Time.zone.parse('2026-04-02T08:30:00Z'))
      end
    end

    context 'with nil' do
      let(:object) do
        override_struct.new(updated_at: nil, cap: 100.0, cap_enabled: true)
      end

      it 'returns nil' do
        expect(override_type.updated_at).to be_nil
      end
    end
  end
end
