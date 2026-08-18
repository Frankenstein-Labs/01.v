# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::OrganizationIsolationFilter, feature_category: :code_review_workflow do
  let(:host_class) do
    Class.new do
      include ApprovalRules::OrganizationIsolationFilter

      def call(groups, organization:)
        filter_cross_organization_groups(groups, organization: organization)
      end
    end
  end

  subject(:filter) { host_class.new }

  describe '#filter_cross_organization_groups' do
    let_it_be(:organization) { create(:organization, :isolated) }
    let_it_be(:other_organization) { create(:organization) }

    let_it_be(:same_org_group) { create(:group, organization: organization) }
    let_it_be(:cross_org_group) { create(:group, organization: other_organization) }

    context 'when the organization is isolated' do
      it 'keeps groups from the same organization' do
        result = filter.call(Group.id_in([same_org_group.id, cross_org_group.id]), organization: organization)

        expect(result).to include(same_org_group)
        expect(result).not_to include(cross_org_group)
      end

      it 'returns an empty set when all groups are cross-org' do
        result = filter.call(Group.id_in([cross_org_group.id]), organization: organization)

        expect(result).to be_empty
      end
    end

    context 'when the organization is not isolated' do
      let_it_be(:non_isolated_org) { create(:organization) }
      let_it_be(:group_in_org) { create(:group, organization: non_isolated_org) }
      let_it_be(:group_outside_org) { create(:group, organization: other_organization) }

      it 'returns all groups unchanged' do
        result = filter.call(
          Group.id_in([group_in_org.id, group_outside_org.id]),
          organization: non_isolated_org
        )

        expect(result).to include(group_in_org, group_outside_org)
      end
    end

    context 'when organization is nil' do
      it 'returns all groups unchanged' do
        groups = Group.id_in([same_org_group.id, cross_org_group.id])
        result = filter.call(groups, organization: nil)

        expect(result).to include(same_org_group, cross_org_group)
      end
    end
  end
end
