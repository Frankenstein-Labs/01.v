# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group or Project invitations', :with_current_organization, :js, :saas, feature_category: :system_access do
  include IdentityVerificationHelpers

  let(:group) { create(:group, name: 'Owned') }
  let(:project) { create(:project, :repository, namespace: group) }
  let(:group_invite) { create(:group_member, :invited, group: group) }
  let(:new_user) { build_stubbed(:user, email: group_invite.invite_email) }

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)

    visit invite_path(group_invite.raw_invite_token)
  end

  it 'bypasses the setup_for_company question' do
    fill_in_sign_up_form(new_user, invite: true)

    expect(page).not_to have_content('My company or team')
  end

  it_behaves_like 'creates a user with ArkoseLabs risk band' do
    let(:signup_path) { invite_path(group_invite.raw_invite_token) }
    let(:user_email) { new_user[:email] }

    subject(:fill_and_submit_signup_form) { fill_in_sign_up_form(new_user, invite: true) }
  end
end
