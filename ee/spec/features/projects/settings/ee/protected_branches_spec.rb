# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Settings > Repository settings using custom role', :js, feature_category: :source_code_management do
  include ProtectedBranchHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:role) { create(:member_role, :guest, :admin_protected_branch, namespace: group) }
  let_it_be(:membership) do
    create(:group_member, :guest, member_role: role, user: current_user, group: group)
  end

  let(:success_message) { s_('ProtectedBranch|Protected branch was successfully created') }

  context 'when user is a guest with custom roles that enables handling protected branches' do
    before do
      stub_licensed_features(custom_roles: true)

      sign_in(current_user)
    end

    it_behaves_like 'setting project protected branches'

    it 'does not show sections not allowed by the custom role', :aggregate_failures do
      expect(page).not_to have_content('Branch defaults')
      expect(page).not_to have_content('Push rules')
      expect(page).not_to have_content('Mirroring repositories')
      expect(page).not_to have_content('Protected tags')
      expect(page).not_to have_content('Deploy tokens')
      expect(page).not_to have_content('Deploy keys')
      expect(page).not_to have_content('Repository maintenance')
    end
  end
end
