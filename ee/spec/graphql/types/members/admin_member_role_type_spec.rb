# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AdminMemberRole'], feature_category: :system_access do
  include GraphqlHelpers

  let(:fields) do
    %w[description id name enabledPermissions usersCount editPath detailsPath createdAt ldapAdminRoleLinks]
  end

  let_it_be(:role) { create(:member_role, :admin) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  specify { expect(described_class.graphql_name).to eq('AdminMemberRole') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  describe 'users count' do
    it 'returns 0 when there are no assigned users' do
      expect(resolve_field(:users_count, role)).to eq(0)
    end

    it 'returns 2 when there are assigned users' do
      user1 = create(:user)
      user2 = create(:user)
      create(:user_member_role, member_role: role, user: user1)
      create(:user_member_role, member_role: role, user: user2)

      expect(resolve_field(:users_count, role)).to eq(2)
    end
  end
end
