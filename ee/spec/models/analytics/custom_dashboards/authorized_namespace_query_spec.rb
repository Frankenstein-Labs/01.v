# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::AuthorizedNamespaceQuery, feature_category: :custom_dashboards_foundation do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }

  let_it_be(:user) { create(:user) }

  let_it_be(:root_group) { create(:group, organization: organization) }
  let_it_be(:subgroup) { create(:group, parent: root_group, organization: organization) }

  let_it_be(:other_org_group) { create(:group, organization: other_organization) }

  # Create memberships directly to bypass organization validation
  let_it_be(:root_group_member) do
    create(:group_member, :reporter, group: root_group, user: user)
  end

  let_it_be(:other_org_member) do
    create(:group_member, :guest, group: other_org_group, user: user)
  end

  describe '.for' do
    context 'when user is nil' do
      it 'returns an empty relation' do
        result = described_class.for(
          nil,
          organization: organization,
          min_access_level: Gitlab::Access::REPORTER
        )

        expect(result).to be_empty
      end
    end

    context 'when user has sufficient access' do
      it 'returns groups the user has access to' do
        result = described_class.for(
          user,
          organization: organization,
          min_access_level: Gitlab::Access::REPORTER
        )

        expect(result).to contain_exactly(root_group, subgroup)
      end

      it 'includes descendant groups' do
        result = described_class.for(
          user,
          organization: organization,
          min_access_level: Gitlab::Access::REPORTER
        )

        expect(result).to include(subgroup)
      end
    end

    context 'when group is in another organization' do
      it 'does not return groups outside the organization' do
        result = described_class.for(
          user,
          organization: organization,
          min_access_level: Gitlab::Access::REPORTER
        )

        expect(result).not_to include(other_org_group)
      end
    end

    context 'when user access level is below minimum' do
      let_it_be(:guest_only_group) { create(:group, organization: organization) }
      let_it_be(:guest_member) do
        create(:group_member, :guest, group: guest_only_group, user: user)
      end

      it 'excludes groups below the required access level' do
        result = described_class.for(
          user,
          organization: organization,
          min_access_level: Gitlab::Access::REPORTER
        )

        expect(result).not_to include(guest_only_group)
      end
    end
  end
end
