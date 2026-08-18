# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Govern::PolicyEnforcement, feature_category: :security_policy_management do
  subject(:enforcement) { build(:govern_policy_enforcement) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:policy).required.inverse_of(:enforcements) }
    it { is_expected.to belong_to(:project).optional }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:state).with_values(active: 0, inactive: 1, completed: 2, failed: 3) }
  end

  describe 'validations' do
    it 'validates uniqueness of project_id scoped to organization and policy' do
      existing = create(:govern_policy_enforcement)
      duplicate = build(:govern_policy_enforcement,
        policy: existing.policy,
        organization: existing.organization,
        project: existing.project)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:project_id]).to include('has already been taken')
    end

    it 'does not constrain rows that target no project against each other' do
      existing = create(:govern_policy_enforcement, project: nil)
      duplicate = build(:govern_policy_enforcement,
        policy: existing.policy,
        organization: existing.organization,
        project: nil)

      expect(duplicate).to be_valid
    end

    it { is_expected.to be_valid }

    it 'defaults to the active state' do
      expect(enforcement.state).to eq('active')
    end

    context 'when the organization does not match the policy organization' do
      subject(:enforcement) { build(:govern_policy_enforcement, organization: build(:organization)) }

      it 'is invalid' do
        expect(enforcement).not_to be_valid
        expect(enforcement.errors[:organization_id]).to include("must match the policy's organization")
      end
    end
  end
end
