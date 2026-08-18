# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedEnvironments::ApprovalRule,
  feature_category: :deployment_management do
  include_context 'with an approval rule and approver'

  describe 'associations' do
    it { is_expected.to have_many(:deployment_approvals).class_name('Deployments::Approval').inverse_of(:approval_rule) }
  end

  it_behaves_like 'authorizable for protected environments',
    factory_name: :protected_environment_approval_rule

  it_behaves_like 'summarizable for deployment approvals'

  describe 'validation' do
    it 'has a limit on required_approvals' do
      is_expected.to validate_numericality_of(:required_approvals)
        .only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5)
    end

    it do
      is_expected.to validate_inclusion_of(:group_inheritance_type)
        .in_array(ProtectedEnvironments::Authorizable::GROUP_INHERITANCE_TYPE.values)
    end
  end

  describe '#hook_attrs' do
    let(:rule) { build_stubbed(:protected_environment_approval_rule, :maintainer_access, required_approvals: 2) }

    subject(:hook_attrs) { rule.hook_attrs }

    it 'returns a static set of attributes', :aggregate_failures do
      expect(hook_attrs.keys).to eq(
        %i[id user_id group_id access_level access_level_description required_approvals group_inheritance_type]
      )
      expect(hook_attrs[:id]).to eq(rule.id)
      expect(hook_attrs[:access_level]).to eq(rule.access_level)
      expect(hook_attrs[:access_level_description]).to eq(rule.humanize)
      expect(hook_attrs[:required_approvals]).to eq(2)
      expect(hook_attrs[:group_inheritance_type]).to eq(rule.group_inheritance_type)
    end
  end
end
