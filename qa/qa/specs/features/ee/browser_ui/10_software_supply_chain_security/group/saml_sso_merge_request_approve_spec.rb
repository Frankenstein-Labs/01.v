# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', :skip_live_env, :orchestrated, :group_saml,
    feature_category: :compliance_management do
    include Runtime::Fixtures

    # The core feature is tested in ee/spec/features/merge_request/user_approves_with_password_spec.rb
    # This spec verifies the same behavior when users authenticate via SAML SSO
    describe 'Merge request approval with SAML SSO' do
      let!(:saml_idp_service) { Flow::Saml.run_saml_idp_service(group.path, [approver, author]) }
      let(:group) { create(:sandbox, path: "group-saml-approval-password-#{SecureRandom.hex(8)}") }
      let(:project) { create(:project, group: group) }
      let(:author) { build(:user) }
      let(:approver) { build(:user) }

      let(:author_api_client) do
        Runtime::API::Client.new(:gitlab, personal_access_token: author.create_personal_access_token!.to_s)
      end

      let(:merge_request) do
        create(:merge_request, project: project, api_client: author_api_client,
          approval_rules: [
            {
              name: "user",
              approvals_required: 1,
              users: [approver]
            }
          ])
      end

      before do
        group_sso_url = Flow::Saml.enable_saml_sso(group, saml_idp_service, enforce_sso: true)
        Runtime::ApplicationSettings.set_application_settings(password_authentication_enabled_for_web: false)

        # Sign in as both users so their SAML and GitLab accounts are linked.
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
        Flow::Saml.sign_in(group_sso_url: group_sso_url, as: author)
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
        Flow::Saml.logout_from_idp(saml_idp_service)
        Flow::Saml.sign_in(group_sso_url: group_sso_url, as: approver)

        group.update_members(author.reload!, approver.reload!, access_level: Resource::Members::AccessLevel::MAINTAINER)

        # TODO: remove with DB field https://gitlab.com/gitlab-org/gitlab/-/issues/431346
        project.update_approval_configuration(require_password_to_approve: true)

        project.update_approval_configuration(require_reauthentication_to_approve: true)
      end

      after do
        saml_idp_service.remove!
        Runtime::ApplicationSettings.set_application_settings(password_authentication_enabled_for_web: true)
      end

      it 'can be approved when requiring a password', quarantine: {
        issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24038',
        type: :investigating
      } do
        merge_request.visit!
        expect(page).to have_text("Approve with SAML", wait: 10)

        Page::MergeRequest::Show.perform do |mr|
          mr.click_approve(verify: false)
          # Redirects to SAML IDP service for authentication, should be seamless
          expect(mr).to be_approved
        end
      end
    end
  end
end
