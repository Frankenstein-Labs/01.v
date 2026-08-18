# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with the `remove_group` custom ability', feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, remove_group: true) }
  let_it_be(:member) { create(:group_member, :guest, member_role: role, user: user, group: group) }
  let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe GroupsController do
    before do
      sign_in(user)
    end

    describe '#edit' do
      it 'user can view the edit page of the subgroup' do
        get edit_group_path(subgroup)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('Delete group'))
      end
    end

    describe '#destroy' do
      it 'user can delete the subgroup' do
        delete group_path(subgroup)

        expect(response).to have_gitlab_http_status(:found)
        expect(subgroup.reload).to be_self_deletion_scheduled
      end
    end

    describe '#restore' do
      before do
        subgroup.schedule_deletion!(transition_user: user)
      end

      it 'user can restore the subgroup' do
        post group_restore_path(subgroup)

        expect(response).to have_gitlab_http_status(:found)
        expect(subgroup.reload).not_to be_self_deletion_scheduled
      end
    end
  end

  describe API::Groups do
    include ApiHelpers

    describe '#delete' do
      it 'user can delete the subgroup' do
        delete api("/groups/#{subgroup.id}", user)

        expect(response).to have_gitlab_http_status(:accepted)
        expect(subgroup.reload).to be_self_deletion_scheduled
      end
    end

    describe '#restore' do
      before do
        subgroup.schedule_deletion!(transition_user: user)
      end

      it 'user can restore the subgroup' do
        post api("/groups/#{subgroup.id}/restore", user)

        expect(response).to have_gitlab_http_status(:created)
        expect(subgroup.reload).not_to be_self_deletion_scheduled
      end
    end
  end
end
