# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User approves with SAML auth', :js, feature_category: :compliance_management, quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24089' do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:setting) do
    create(
      :group_merge_request_approval_setting,
      require_saml_auth_to_approve: true,
      require_password_to_approve: true, # enable password to test that SAML takes precedence
      group: group
    )
  end

  let_it_be(:sub_group) { create :group, parent: group }
  let_it_be(:project) do
    create :project,
      :public,
      :repository,
      group: sub_group,
      approvals_before_merge: 1,
      merge_requests_author_approval: true,
      maintainers: user
  end

  let_it_be(:owner) { project.first_owner }
  let_it_be(:merge_request) { create :merge_request_with_diffs, source_project: project, reviewers: [user] }

  # This emulates a successful response by the SAML provider
  around do |example|
    with_omniauth_full_host { example.run }
  end

  before do
    stub_default_url_options(protocol: "https")
    stub_licensed_features(group_saml: true)
    create(:saml_provider, group: group, enabled: true)
    mock_group_saml(uid: '1')
  end

  def sign_in_and_connect_saml_identity
    # new users have to link their account to their SAML identity provider first
    sign_in(user)
    visit sso_group_saml_providers_path group_id: group, token: group.saml_discovery_token
    wait_for_requests
    has_testid?('saml-sso-signin-button')
    click_link 'Authorize'
    wait_for_requests
  end

  def approve_with_saml
    visit project_merge_request_path(project, merge_request)
    page.within('.js-mr-approvals') { click_button 'Approve with SAML' }
  end

  def revoke_approval
    click_button 'Revoke approval'
    wait_for_requests
  end

  it 'shows user can approve and unapprove',
    quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17073' do
    sign_in_and_connect_saml_identity

    # approval
    approve_with_saml

    expect(page).to have_text('Approved')

    page.within('.js-mr-approvals') do
      expect(page).not_to have_button('Approve with SAML')
      expect(page).to have_text('Approved by you')
    end

    # revoke approval
    revoke_approval

    expect(page).to have_button('Approve with SAML')
    expect(page).not_to have_text('Approved by')

    # flash message with error when approval fails
    allow_next_instance_of(::MergeRequests::ApprovalService) do |approval_service|
      allow(approval_service).to receive(:execute).and_return(nil)
    end
    visit saml_approval_namespace_project_merge_request_path(group, project, merge_request)

    approve_with_saml
    expect(page).to have_text('Approval rejected')
  end
end
