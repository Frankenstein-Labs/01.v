# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User visits public profile', feature_category: :user_profile do
  context 'when user profile is provisioned by group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:scim_identity) { create(:scim_identity, group: group) }
    let_it_be(:user) { create(:user, :public_email, provisioned_by_group_id: scim_identity.group.id) }

    it 'displays public_email' do
      visit(user_path(user))
      expect(page).to have_content user.public_email
    end
  end
end
