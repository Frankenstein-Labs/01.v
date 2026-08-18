# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::FrameworkPolicy, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: group) }

  let(:licensed_compliance_features) do
    {
      custom_compliance_frameworks: true,
      evaluate_group_level_compliance_pipeline: true,
      group_level_compliance_adherence_report: true
    }
  end

  subject { described_class.new(user, framework) }

  shared_examples 'full access to compliance framework administration' do
    it { is_expected.to be_allowed(:admin_compliance_framework) }
    it { is_expected.to be_allowed(:read_compliance_framework) }
    it { is_expected.to be_allowed(:admin_compliance_pipeline_configuration) }
  end

  shared_examples 'read only access to compliance framework' do
    it { is_expected.to be_disallowed(:admin_compliance_framework) }
    it { is_expected.to be_allowed(:read_compliance_framework) }
    it { is_expected.to be_disallowed(:admin_compliance_pipeline_configuration) }
  end

  shared_examples 'no access to compliance framework administration' do
    it { is_expected.to be_disallowed(:admin_compliance_framework) }
    it { is_expected.to be_disallowed(:read_compliance_framework) }
    it { is_expected.to be_disallowed(:admin_compliance_pipeline_configuration) }
  end

  context 'feature is licensed' do
    before do
      stub_licensed_features(licensed_compliance_features)
    end

    context 'user is group owner' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'full access to compliance framework administration'
    end

    context 'user is not a member of the namespace' do
      let_it_be(:user) { create(:user) }

      it_behaves_like 'no access to compliance framework administration'
    end

    context 'user is an admin', :enable_admin_mode do
      let(:user) { build(:admin) }

      it_behaves_like 'full access to compliance framework administration'
    end

    context 'when user is a guest with admin_compliance_framework custom permission' do
      let_it_be(:user) { create(:user) }
      let_it_be(:member_role) do
        create(:member_role, :guest, :admin_compliance_framework, namespace: group)
      end

      let_it_be(:member) do
        create(:group_member, :guest, group: group, user: user, member_role: member_role)
      end

      context 'when custom_roles feature is disabled' do
        it { is_expected.to be_allowed(:read_compliance_framework) }
        it { is_expected.to be_disallowed(:admin_compliance_framework) }
        it { is_expected.to be_disallowed(:admin_compliance_pipeline_configuration) }
      end

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(licensed_compliance_features.merge(custom_roles: true))
        end

        it_behaves_like 'full access to compliance framework administration'
      end
    end

    context 'user is subgroup member but not the owner of the root namespace' do
      let_it_be(:user) { create(:user) }

      let_it_be(:subgroup) { create(:group, :private, parent: group) }

      before_all do
        group.add_developer(user)
        subgroup.add_maintainer(user)
      end

      it_behaves_like 'read only access to compliance framework'
    end
  end

  context 'feature is unlicensed' do
    before do
      stub_licensed_features(
        custom_compliance_frameworks: false,
        evaluate_group_level_compliance_pipeline: false,
        group_level_compliance_adherence_report: false
      )
    end

    it_behaves_like 'no access to compliance framework administration'
  end
end
