# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_group_member custom role', feature_category: :groups_and_projects do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_group_member: true) }
  let_it_be(:membership) do
    create(:group_member, :developer, member_role: role, user: current_user, group: group)
  end

  let_it_be(:group_member) { create(:group_member, :developer, group: group) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(current_user)
  end

  describe Groups::GroupMembersController do
    describe '#update' do
      it 'user can update a member to a guest via a custom role' do
        put group_group_member_path(group_id: group, id: group_member), params: {
          group_member: {
            access_level: Gitlab::Access::GUEST
          }
        }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'user can not update a member to a maintainer via a custom role' do
        put group_group_member_path(group_id: group, id: group_member), params: {
          group_member: {
            access_level: Gitlab::Access::MAINTAINER
          }
        }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe '#delete' do
      it 'user can delete a member via a custom role' do
        delete group_group_member_path(group_id: group, id: group_member)

        expect(response).to have_gitlab_http_status(:see_other)
        expect(flash[:notice]).to eq('User was successfully removed from group.')
      end
    end

    describe '#approve_access_request' do
      let_it_be(:access_request) { create(:group_member, :guest, :access_request, group: group) }

      it 'user can delete a member via a custom role' do
        post approve_access_request_group_group_member_path(group_id: group, id: access_request)

        expect(response).to redirect_to(group_group_members_path(group))
        expect(group.members).to include(access_request)
      end
    end
  end
end
