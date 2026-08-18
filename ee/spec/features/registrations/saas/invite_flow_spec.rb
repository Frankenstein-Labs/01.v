# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SaaS registration from an invite', :with_current_organization, :js, :saas_registration, :sidekiq_inline, feature_category: :onboarding do
  it 'registers the user and sends them to the group page' do
    group = create(:group, name: 'Test Group')

    registers_from_invite(group: group)

    ensure_onboarding { expect_to_see_welcome_form_for_invites }
    expect_to_send_iterable_request(invite: true)

    fill_in_welcome_form
    click_on 'Get started!'

    expect_to_be_on_page_for(group)
    ensure_onboarding_is_finished
  end

  it 'registers the user with identity verification and sends them to the group page' do
    group = create(:group, name: 'Test Group')

    registers_from_invite_with_arkose(group: group)

    expect_to_see_identity_verification_page

    verify_phone_number(solve_arkose_challenge: true)

    expect_verification_completed

    ensure_onboarding { expect_to_see_welcome_form_for_invites }
    expect_to_send_iterable_request(invite: true)

    fill_in_welcome_form
    click_on 'Get started!'

    expect_to_be_on_page_for(group)
    ensure_onboarding_is_finished
  end

  it 'registers the user with multiple invites and sends them to the last group page' do
    group = create(:group, name: 'Test Group', organization: create(:organization))

    create(
      :group_member,
      :invited,
      :developer,
      invite_email: user_email,
      source: create(:group, name: 'Another Test Group')
    )

    registers_from_invite(group: group)

    ensure_onboarding { expect_to_see_welcome_form_for_invites }
    expect_to_send_iterable_request(invite: true)

    fill_in_welcome_form
    click_on 'Get started!'

    expect(page).to have_current_path(group_path(group), ignore_query: true)
    ensure_onboarding_is_finished
  end

  context 'when the invite email is not lowercased' do
    it 'registers the user and sends them to the group page' do
      group = create(:group, name: 'Test Group')

      registers_from_invite(group: group, invite_email: user_email.upcase)

      ensure_onboarding { expect_to_see_welcome_form_for_invites }
      expect_to_send_iterable_request(invite: true)

      fill_in_welcome_form
      click_on 'Get started!'

      expect_to_be_on_page_for(group)
      ensure_onboarding_is_finished
    end
  end

  def registers_from_invite_with_arkose(group:)
    # SaaS has identity verification enabled and this is needed for all that go through identity verification
    # which is anything higher than low risk bands
    stub_application_setting(
      arkose_labs_public_api_key: 'public_key',
      arkose_labs_private_api_key: 'private_key'
    )

    registers_from_invite(group: group) do
      solve_arkose_verify_challenge(risk: :medium)
    end
  end

  def registers_from_invite(group:, invite_email: user_email)
    new_user = build(:user, name: 'Registering User', email: user_email)
    invitation = create(
      :group_member,
      :invited,
      :developer,
      invite_email: invite_email,
      source: group
    )

    visit invite_path(invitation.raw_invite_token, invite_type: ::Members::InviteMailer::INITIAL_INVITE)

    # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/438017
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(110)

    fill_in_sign_up_form(new_user, invite: true) do
      yield if block_given? # rubocop:disable RSpec/AvoidConditionalStatements -- Not applicable here due to controlling the yield
    end
  end

  def fill_in_welcome_form
    select 'Software Developer', from: 'user_onboarding_status_role'
    select 'A different reason', from: 'user_onboarding_status_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'
  end
end
