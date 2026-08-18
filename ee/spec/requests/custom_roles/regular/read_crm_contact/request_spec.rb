# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_crm_contact custom role', feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:role) { create(:member_role, :guest, :read_crm_contact, namespace: group) }
  let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe Groups::Crm::ContactsController do
    describe '#index' do
      it 'allows access' do
        get group_crm_contacts_path(group)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when crm is disabled' do
        let_it_be(:group) { create(:group, :crm_disabled) }

        it 'does not circumvent disabled feature' do
          get group_crm_contacts_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
