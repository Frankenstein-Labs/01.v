# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::SecurityPolicy, feature_category: :security_policy_management do
  describe 'Associations' do
    subject { build(:compliance_framework_security_policy) }

    it { is_expected.to belong_to(:framework) }
    it { is_expected.to belong_to(:policy_configuration) }
    it { is_expected.to belong_to(:security_policy) }
    it { is_expected.to belong_to(:namespace).optional }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to have_many(:security_policy_requirements) }

    it { is_expected.to have_many(:compliance_requirements).through(:security_policy_requirements) }
  end

  describe 'validations' do
    context 'when security_policy is not present' do
      let_it_be(:compliance_framework_security_policy) do
        create(:compliance_framework_security_policy, security_policy: nil)
      end

      it 'validates uniqueness of framework scoped to policy_configuration_id and policy_index' do
        expect(
          build(:compliance_framework_security_policy,
            framework: compliance_framework_security_policy.framework,
            policy_configuration: compliance_framework_security_policy.policy_configuration,
            policy_index: compliance_framework_security_policy.policy_index
          )
        ).to be_invalid
      end
    end

    context 'when security_policy is present' do
      let_it_be(:security_policy) { create(:security_policy) }
      let_it_be(:compliance_framework_security_policy) do
        create(:compliance_framework_security_policy, security_policy: security_policy)
      end

      it 'validates uniqueness of framework scoped to security_policy_id' do
        expect(
          build(:compliance_framework_security_policy,
            framework: compliance_framework_security_policy.framework,
            security_policy: security_policy
          )
        ).to be_invalid
      end
    end
  end

  describe '.for_framework' do
    let_it_be(:framework_1) { create(:compliance_framework) }
    let_it_be(:framework_2) { create(:compliance_framework) }
    let_it_be(:policy_1) { create(:compliance_framework_security_policy, framework: framework_1) }
    let_it_be(:policy_2) { create(:compliance_framework_security_policy, framework: framework_2) }

    subject { described_class.for_framework(framework_1) }

    it { is_expected.to eq([policy_1]) }
  end

  describe '.for_security_policy' do
    let_it_be(:security_policy) { create(:security_policy) }
    let_it_be(:other_security_policy) { create(:security_policy) }
    let_it_be(:compliance_framework) { create(:compliance_framework) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let_it_be(:security_policy_link) do
      create(:compliance_framework_security_policy,
        security_policy: security_policy,
        framework: compliance_framework,
        policy_configuration: policy_configuration
      )
    end

    let_it_be(:other_security_policy_link) do
      create(:compliance_framework_security_policy,
        security_policy: other_security_policy,
        framework: compliance_framework,
        policy_configuration: policy_configuration
      )
    end

    it 'returns security policy links for the given security policy' do
      expect(described_class.for_security_policy(security_policy)).to contain_exactly(security_policy_link)
    end

    it 'returns empty when no security policy links exist for the given security policy' do
      expect(described_class.for_security_policy(create(:security_policy))).to be_empty
    end
  end

  describe '.relink' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 0)
    end

    let_it_be(:other_security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: policy_configuration, policy_index: 1)
    end

    let_it_be(:framework) { create(:compliance_framework) }
    let_it_be(:other_framework) { create(:compliance_framework) }

    let(:framework_policy_attrs) do
      [
        {
          security_policy_id: security_policy.id,
          framework_id: framework.id,
          policy_configuration_id: policy_configuration.id,
          policy_index: security_policy.policy_index
        }
      ]
    end

    subject(:relink) { described_class.relink(security_policy, framework_policy_attrs) }

    context 'when there are no already existing policies' do
      it 'creates new record' do
        relink

        expect(described_class.count).to eq(1)
        expect(described_class.first).to have_attributes(
          framework: framework,
          security_policy: security_policy
        )
      end
    end

    context 'when there are already existing policies' do
      let_it_be(:policy_link) do
        create(:compliance_framework_security_policy,
          framework: framework,
          security_policy: security_policy
        )
      end

      let_it_be(:other_policy_link) do
        create(:compliance_framework_security_policy,
          framework: other_framework,
          security_policy: other_security_policy
        )
      end

      it 'deletes and recreates policy with updated attributes' do
        relink

        expect { policy_link.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end

      it 'does not update count' do
        expect { relink }.not_to change { described_class.count }
      end

      it 'does not update other policies' do
        expect { relink }.not_to change { other_policy_link.reload }
      end
    end
  end
end
