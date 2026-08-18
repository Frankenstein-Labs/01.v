# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::DeploymentTransition, feature_category: :continuous_delivery do
  let_it_be(:deployment) { create(:cd_deployment) }

  describe 'factory' do
    it 'creates a valid deployment transition using factory defaults' do
      expect(create(:cd_deployment_transition)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:deployment).required }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'enums' do
    it 'defines from_state enum with a prefix' do
      is_expected.to define_enum_for(:from_state)
        .with_values(initial: 0, pending: 1, deploying: 2, healthy: 3, degraded: 4, failed: 5, cancelled: 6)
        .with_prefix(:from)
    end

    it 'defines to_state enum with a prefix' do
      is_expected.to define_enum_for(:to_state)
        .with_values(initial: 0, pending: 1, deploying: 2, healthy: 3, degraded: 4, failed: 5, cancelled: 6)
        .with_prefix(:to)
    end
  end

  describe 'validations' do
    subject { build(:cd_deployment_transition, deployment: deployment) }

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
      transition = create(:cd_deployment_transition, deployment: deployment)

      expect { transition.update!(reason: 'changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'scopes' do
    describe '.ordered' do
      it 'returns transitions ordered by created_at ascending' do
        # Created newest-first so the assertion proves the scope reorders them.
        newer = create(:cd_deployment_transition, deployment: deployment, created_at: 1.day.ago)
        older = create(:cd_deployment_transition, deployment: deployment, created_at: 2.days.ago)

        expect(described_class.ordered).to eq([older, newer])
      end
    end
  end

  describe 'sharding key' do
    subject { build(:cd_deployment_transition, deployment: deployment) }

    it { is_expected.to populate_sharding_key(:organization_id).with(deployment.organization_id) }
  end
end
