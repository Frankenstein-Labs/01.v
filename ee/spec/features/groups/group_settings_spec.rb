# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Edit group settings', :js, feature_category: :groups_and_projects do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be_with_refind(:group) { create(:group, name: 'Foo bar', path: 'foo', owners: user, developers: developer) }
  let_it_be_with_refind(:subproject) { create(:project, group: group) }

  before do
    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive_messages(credits_available?: true, usage_billing_forbidden?: false)
    end
    sign_in(user)
  end

  describe 'navbar' do
    context 'with LDAP enabled' do
      before do
        allow_next_found_instance_of(Group) do |instance|
          allow(instance).to receive(:ldap_synced?).and_return(true)
        end
        allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
      end

      it 'is able to navigate to LDAP group section' do
        visit edit_group_path(group)

        within_testid('super-sidebar') do
          expect(page).to have_content('LDAP Synchronization')
        end
      end

      context 'with owners not being able to manage LDAP' do
        it 'is not able to navigate to LDAP group section' do
          stub_application_setting(allow_group_owners_to_manage_ldap: false)

          visit edit_group_path(group)

          within_testid('super-sidebar') do
            expect(page).not_to have_content('LDAP Synchronization')
          end
        end
      end
    end
  end

  context 'with webhook feature enabled' do
    it 'shows the menu item' do
      stub_licensed_features(group_webhooks: true)

      visit edit_group_path(group)

      within_testid('super-sidebar') do
        expect(page).to have_link('Webhooks')
      end
    end
  end

  context 'with webhook feature disabled' do
    it 'does not show the menu item' do
      stub_licensed_features(group_webhooks: false)

      visit edit_group_path(group)

      within_testid('super-sidebar') do
        expect(page).not_to have_link('Webhooks')
      end
    end
  end

  describe 'Member Lock setting' do
    let(:membership_lock_text) { 'Users cannot be added to projects in this group' }

    context 'without a license key' do
      before do
        License.destroy_all # rubocop: disable Cop/DestroyAll
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content(membership_lock_text)
      end

      context 'available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'is visible' do
          visit edit_group_path(group)

          expect(page).to have_content(membership_lock_text)
        end

        context 'when current user is not the Owner' do
          before do
            sign_in(developer)
          end

          it 'is not visible' do
            visit edit_group_path(group)

            expect(page).not_to have_content(membership_lock_text)
          end
        end
      end
    end

    context 'with a license key' do
      it 'is visible' do
        visit edit_group_path(group)

        expect(page).to have_content(membership_lock_text)
      end

      context 'when current user is not the Owner' do
        before do
          sign_in(developer)
        end

        it 'is not visible' do
          visit edit_group_path(group)

          expect(page).not_to have_content(membership_lock_text)
        end
      end
    end
  end

  describe 'Group file templates setting', :js do
    context 'without a license key' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content('Select a template repository')
      end

      context 'available through usage ping features' do
        before do
          stub_usage_ping_features(true)
        end

        it 'is visible' do
          visit edit_group_path(group)

          expect(page).to have_content('Select a template repository')
        end

        context 'when current user is not the Owner' do
          before do
            sign_in(developer)
          end

          it 'is not visible' do
            visit edit_group_path(group)

            expect(page).not_to have_content('Select a template repository')
          end
        end
      end
    end

    context 'with a license key' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      it 'is visible' do
        visit edit_group_path(group)

        expect(page).to have_content('Select a template repository')
      end

      it 'allows a project to be selected', :js do
        project = create(:project, namespace: group, name: 'known project')

        visit edit_group_path(group)

        page.within('section#js-templates') do
          select_from_listbox(project.name_with_namespace, from: 'Search for project')
          click_button 'Save changes'
        end

        expect(page).to have_content("Group 'Foo bar' was successfully updated.")
        expect(group.reload.checked_file_template_project).to eq(project)
      end

      context 'when current user is not the Owner' do
        before do
          sign_in(developer)
        end

        it 'is not visible' do
          visit edit_group_path(group)

          expect(page).not_to have_content('Select a template repository')
        end
      end
    end
  end

  context 'when custom_project_templates feature' do
    let!(:subgroup) { create(:group, :public, parent: group) }
    let!(:subgroup_1) { create(:group, :public, parent: subgroup) }

    shared_examples 'shows custom project templates settings' do
      it 'shows the custom project templates selection menu' do
        expect(page).to have_content('Custom project templates')
      end

      context 'group selection menu', :js do
        it 'shows only the subgroups' do
          within_testid('custom-project-templates-container') do
            click_button 'Search for a group'
          end

          expect_listbox_items([/#{nested_group.full_name}\s+#{nested_group.full_path}/])
        end
      end
    end

    shared_examples 'does not show custom project templates settings' do
      it 'does not show the custom project templates selection menu' do
        expect(page).not_to have_content('Custom project templates')
      end
    end

    context 'is enabled' do
      before do
        stub_licensed_features(group_project_templates: true)
        visit edit_group_path(selected_group)
      end

      context 'when the group is a top parent group' do
        let(:selected_group) { group }
        let(:nested_group) { subgroup }

        it_behaves_like 'shows custom project templates settings'
      end

      context 'when the group is a subgroup' do
        let(:selected_group) { subgroup }
        let(:nested_group) { subgroup_1 }

        it_behaves_like 'shows custom project templates settings'
      end
    end

    context 'namespace plan is checked', :saas do
      before do
        create(:gitlab_subscription, namespace: group, hosted_plan: plan)
        stub_licensed_features(group_project_templates: true)
        allow(Gitlab::CurrentSettings.current_application_settings)
          .to receive(:should_check_namespace_plan?).and_return(true)

        visit edit_group_path(selected_group)
      end

      context 'namespace is on the proper plan' do
        let(:plan) { create(:ultimate_plan) }

        context 'when the group is a top parent group' do
          let(:selected_group) { group }
          let(:nested_group) { subgroup }

          it_behaves_like 'shows custom project templates settings'
        end

        context 'when the group is a subgroup' do
          let(:selected_group) { subgroup }
          let(:nested_group) { subgroup_1 }

          it_behaves_like 'shows custom project templates settings'
        end
      end

      context 'is disabled for namespace' do
        let(:plan) { create(:bronze_plan) }

        context 'when the group is the top parent group' do
          let(:selected_group) { group }

          it_behaves_like 'does not show custom project templates settings'
        end

        context 'when the group is a subgroup' do
          let(:selected_group) { subgroup }

          it_behaves_like 'does not show custom project templates settings'
        end
      end
    end

    context 'is disabled' do
      before do
        stub_licensed_features(group_project_templates: false)
        visit edit_group_path(selected_group)
      end

      context 'when the group is the top parent group' do
        let(:selected_group) { group }

        it_behaves_like 'does not show custom project templates settings'
      end

      context 'when the group is a subgroup' do
        let(:selected_group) { subgroup }

        it_behaves_like 'does not show custom project templates settings'
      end
    end
  end

  describe 'merge request approval settings', :js do
    let_it_be(:approval_settings) do
      create(:group_merge_request_approval_setting, group: group, allow_author_approval: false)
    end

    context 'when group is licensed' do
      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      it 'allows to save settings' do
        visit edit_group_path(group)
        wait_for_all_requests

        expect(page).to have_content('Merge request approvals')

        within_testid('merge-request-approval-settings') do
          click_button 'Expand'
          checkbox = find_field('Prevent approval by merge request creator')
          expect(checkbox).to be_checked

          checkbox.set(false)
          click_button 'Save changes'
          wait_for_all_requests
        end

        visit edit_group_path(group)
        wait_for_all_requests

        within_testid('merge-request-approval-settings') do
          click_button 'Expand'

          expect(find_field('Prevent approval by merge request creator')).not_to be_checked
        end
      end
    end

    context 'when group is not licensed' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'is not visible' do
        visit edit_group_path(group)

        expect(page).not_to have_content('Merge request approvals')
      end
    end
  end

  describe 'permissions and group features', :js do
    context 'for service access token enforced setting' do
      context 'when saas', :saas do
        context 'when service accounts feature enabled' do
          it 'renders service access token enforced checkbox' do
            visit edit_group_path(group)
            wait_for_all_requests

            expect(page).to have_content(s_('AccessTokens|Require expiration dates for service accounts'))

            within(permissions_selector) do
              checkbox = find(service_access_token_expiration_enforced_selector)

              expect(checkbox).to be_checked

              checkbox.set(false)
              click_button 'Save changes'
              wait_for_all_requests
            end

            visit edit_group_path(group)
            wait_for_all_requests

            within(permissions_selector) do
              expect(find(service_access_token_expiration_enforced_selector)).not_to be_checked
            end
          end

          context 'when group is not the root group' do
            let(:subgroup) { create(:group, parent: group) }

            it "does not render service account token enforced checkbox" do
              visit edit_group_path(subgroup)
              wait_for_all_requests

              expect(page).not_to have_content('Service account token expiration')
            end
          end
        end

        context 'Dormant members', :aggregate_failures, feature_category: :user_management do
          before do
            visit edit_group_path(group)
          end

          it 'exposes the setting section' do
            expect(page).to have_content('Dormant members')
            expect(page).to have_content('Read these instructions to understand the implications of enabling this setting. Removed members no longer have access to this top-level group, its subgroups, and their projects.')
            expect(page).to have_field('Remove dormant members after a period of inactivity')
            expect(page).to have_field('Days of inactivity before removal', disabled: true)
          end

          it 'changes dormant members', :js do
            expect(page).to have_unchecked_field(_('Remove dormant members after a period of inactivity'))
            expect(group.namespace_settings.remove_dormant_members).to be_falsey

            within_testid('permissions-settings') do
              check _('Remove dormant members after a period of inactivity')
              fill_in _('Days of inactivity before removal'), with: '90'
              click_button _('Save changes')
            end

            expect(page).to have_content(
              format(
                _("Group '%{group_name}' was successfully updated."),
                group_name: group.name
              )
            )

            page.refresh

            expect(page).to have_checked_field(_('Remove dormant members after a period of inactivity'))
            expect(page).to have_field(_('Days of inactivity before removal'), disabled: false, with: '90')
          end

          it 'displays dormant members period field validation error', :js do
            selector = '#group_remove_dormant_members_period_error'
            expect(page).not_to have_selector(selector, visible: :visible)

            within_testid('permissions-settings') do
              check _('Remove dormant members after a period of inactivity')
              fill_in _('Days of inactivity before removal'), with: '30'
              click_button 'Save changes'
            end

            expect(page).to have_selector(selector, visible: :visible)
            expect(page).to have_content _('Please enter a value between 90 and 1827 days (5 years)')
          end

          it 'auto disables dormant members period field depending on parent checkbox', :js do
            uncheck _('Remove dormant members after a period of inactivity')
            expect(page).to have_field(_('Days of inactivity before removal'), disabled: true)

            check _('Remove dormant members after a period of inactivity')
            expect(page).to have_field(_('Days of inactivity before removal'), disabled: false)
          end
        end
      end

      context 'when not saas' do
        it "does not render service access token enforced checkbox" do
          visit edit_group_path(group)
          wait_for_all_requests

          expect(page).not_to have_content('Service account token expiration')
        end

        it "does not render dormant member section" do
          expect(page).not_to have_content('Dormant members')
          expect(page).not_to have_field('Remove dormant members after a period of inactivity')
          expect(page).not_to have_field('Days of inactivity before removal', disabled: true)
        end
      end

      def service_access_token_expiration_enforced_selector
        '[data-testid="service_access_tokens_expiration_enforced_checkbox"]'
      end
    end

    context 'for gitlab credits dashboard' do
      context 'when in saas', :saas_gitlab_com_subscriptions do
        context 'when group does not have usage billing feature' do
          before do
            stub_licensed_features(group_usage_billing: false)
          end

          it 'hides display user data checkbox' do
            visit edit_group_path(group)

            within_testid('permissions-settings') do
              expect(page).not_to have_content('GitLab Credits dashboard')
              expect(page).not_to have_content('Display user data')
            end
          end

          it 'shows the checkbox when group has an active gitlab_credits add-on' do
            create(:gitlab_subscription_add_on_purchase, :gitlab_credits, :active, namespace: group)

            visit edit_group_path(group)

            within_testid('permissions-settings') do
              expect(page).to have_content('GitLab Credits dashboard')
              expect(page).to have_content('Display user data')
            end
          end
        end

        context 'when group has usage billing feature' do
          before do
            stub_licensed_features(group_usage_billing: true)
            visit edit_group_path(group)
          end

          it 'shows the display user data checkbox' do
            within_testid('permissions-settings') do
              expect(page).to have_content('GitLab Credits dashboard')
              expect(page).to have_content('Display user data')
            end
          end

          it 'changes display user data', :js do
            expect(group.namespace_settings.display_gitlab_credits_user_data).to be_truthy
            within_testid('permissions-settings') do
              expect(page).to have_checked_field(_('Display user data'))
            end

            within_testid('permissions-settings') do
              uncheck _('Display user data')
              click_button _('Save changes')
            end

            expect(page).to have_content(
              format(
                _("Group '%{group_name}' was successfully updated."),
                group_name: group.name
              )
            )

            page.refresh

            expect(page).to have_unchecked_field(_('Display user data'))
          end
        end
      end

      context 'when not in saas' do
        it 'does not show the checkbox' do
          stub_licensed_features(group_usage_billing: true)

          visit edit_group_path(group)

          within_testid('permissions-settings') do
            expect(page).not_to have_content('GitLab Credits dashboard')
            expect(page).not_to have_content('Display user data')
          end
        end
      end
    end

    context 'for disable personal access tokens setting' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      it 'does not render disable personal access tokens setting' do
        visit edit_group_path(group)
        wait_for_all_requests

        within(permissions_selector) do
          expect(page).not_to have_content(s_('GroupSettings|Disable personal access tokens'))
        end
      end

      context 'for SaaS', :saas do
        before do
          stub_licensed_features(domain_verification: true, disable_personal_access_tokens: true)
          stub_saas_features(disable_personal_access_tokens: true)
        end

        it 'renders disable personal access tokens setting' do
          visit edit_group_path(group)
          wait_for_all_requests

          within(permissions_selector) do
            expect(page).to have_content(s_('GroupSettings|Disable personal access tokens'))
          end
        end
      end
    end

    context 'for disable SSH Keys setting' do
      before do
        stub_licensed_features(disable_ssh_keys: true)
      end

      context 'when on self-managed' do
        it 'does not render disable SSH Keys setting' do
          visit edit_group_path(group)
          wait_for_all_requests

          within(permissions_selector) do
            expect(page).not_to have_content(s_('GroupSettings|Disable SSH Keys'))
          end
        end
      end

      context 'for SaaS', :saas do
        before do
          stub_licensed_features(domain_verification: true, disable_ssh_keys: true)
          stub_saas_features(disable_ssh_keys: true)
        end

        it 'renders disable SSH Keys setting' do
          visit edit_group_path(group)
          wait_for_all_requests

          within(permissions_selector) do
            expect(page).to have_content(s_('GroupSettings|Disable SSH Keys'))
          end
        end
      end
    end

    context 'for disable_invite_members setting' do
      before do
        stub_licensed_features(disable_invite_members: true)
      end

      context 'when SaaS', :saas do
        context 'for a top-level group' do
          context 'for a licensed group' do
            it 'shows disable-invitations setting' do
              visit edit_group_path(group)
              wait_for_all_requests

              within(permissions_selector) do
                expect(page).to have_content(_('User invitation restrictions'))
              end
            end
          end

          context 'for a non-licensed group' do
            before do
              stub_licensed_features(disable_invite_members: false)
            end

            it 'hides disable-invitations group setting' do
              visit edit_group_path(group)
              wait_for_all_requests
              expect(page).not_to have_content(_('User invitation restrictions'))
            end
          end
        end

        context 'for a not top-level group' do
          let_it_be_with_refind(:subgroup) { create(:group, parent: group) }

          it 'hides disable-invitations group setting' do
            visit edit_group_path(subgroup)
            wait_for_all_requests
            expect(page).not_to have_content(_('User invitation restrictions'))
          end
        end
      end

      context 'when not SaaS' do
        it 'hides disable-invitations group setting' do
          visit edit_group_path(group)
          wait_for_all_requests
          expect(page).not_to have_content(_('User invitation restrictions'))
        end
      end
    end

    context 'allow personal snippets', :saas do
      before do
        stub_licensed_features(domain_verification: true, allow_personal_snippets: true)
        stub_saas_features(allow_personal_snippets: true)
        allow(group).to receive(:domain_verification_available?).and_return(true)
      end

      it 'renders allow personal snippets setting' do
        visit edit_group_path(group)
        wait_for_all_requests

        within(permissions_selector) do
          expect(page).to have_content(s_('GroupSettings|Allow personal snippets'))
        end
      end

      it 'saves the setting', :js do
        visit edit_group_path(group)
        wait_for_all_requests

        within(permissions_selector) do
          uncheck 'Allow personal snippets'
          click_button 'Save changes'
        end

        wait_for_all_requests
        expect(page).to have_content("Group 'Foo bar' was successfully updated.")
        expect(group.reload.namespace_settings.allow_personal_snippets).to be(false)
      end
    end

    def permissions_selector
      '[data-testid="permissions-settings"]'
    end
  end

  describe 'email domain validation', :js do
    let(:domain_field_selector) { '[placeholder="example.com"]' }

    before do
      stub_licensed_features(group_allowed_email_domains: true)
    end

    def update_email_domains(new_domain)
      visit edit_group_path(group)

      find(domain_field_selector).set(new_domain)
      find(domain_field_selector).send_keys(:enter)
    end

    it 'is visible' do
      visit edit_group_path(group)

      expect(page).to have_content("Restrict membership by email domain")
    end

    it 'displays an error for invalid emails' do
      new_invalid_domain = "gitlab./com!"

      update_email_domains(new_invalid_domain)

      expect(page).to have_content("The domain you entered is misformatted")
    end

    it 'saves valid domains' do
      new_domain = "gitlab.com"

      update_email_domains(new_domain)

      expect(page).not_to have_content("The domain you entered is misformatted")
      within_testid("permissions-settings") do
        click_button 'Save changes'
      end
      wait_for_requests

      expect(page).to have_content("Group 'Foo bar' was successfully updated.")
    end
  end

  describe 'seat control settings' do
    let(:user_cap_available) { true }

    before do
      allow_next_found_instance_of(Group) do |instance|
        allow(instance).to receive(:user_cap_available?).and_return user_cap_available
      end
    end

    context 'when user cap feature is unavailable' do
      let(:user_cap_available) { false }

      before do
        visit edit_group_path(group)
      end

      it 'is not visible' do
        expect(page).not_to have_content('Seat control')
        expect(page).not_to have_content('Restricted access')
        expect(page).not_to have_content('Set user cap')
      end
    end

    context 'when user cap feature is available', :js, :saas do
      let(:user_caps_selector) { '[name="group[new_user_signups_cap]"]' }

      context 'with no subscription' do
        before do
          visit edit_group_path(group)
        end

        it 'is visible' do
          expect(page).to have_content('Seat control')
          expect(page).to have_content('Set user cap')
        end

        it 'is not visible' do
          expect(page).not_to have_content('Restricted access')
        end
      end

      context 'with a subscription' do
        let!(:subscription) { create(:gitlab_subscription, :ultimate, namespace: group) }

        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:should_check_namespace_plan?).and_return(true)
        end

        context 'when group is not the root group' do
          let(:subgroup) { create(:group, parent: group) }

          before do
            visit edit_group_path(subgroup)
          end

          it 'is not visible' do
            expect(page).not_to have_content('Seat control')
            expect(page).not_to have_content('Restricted access')
            expect(page).not_to have_content('Set user cap')
          end
        end

        context 'when the group is the root group' do
          before do
            visit edit_group_path(group)
          end

          it 'is visible' do
            expect(page).to have_content('Seat control')
            expect(page).to have_content('Set user cap')
            expect(page).to have_content('Restricted access')
          end

          it 'saves positive numbers for the user cap' do
            find_by_testid("seat-control-user-cap-radio").click

            find(user_caps_selector).set(5)
            within_testid("permissions-settings") do
              click_button 'Save changes'
            end

            wait_for_requests

            expect(page).to have_content("Group 'Foo bar' was successfully updated.")
          end

          it 'does not allow a negative number for the user cap' do
            find_by_testid("seat-control-user-cap-radio").click

            find(user_caps_selector).set(-5)

            within_testid("permissions-settings") do
              click_button 'Save changes'
            end
            expect(page).to have_content('This field is required.')

            wait_for_requests

            expect(page).not_to have_content("Group 'Foo bar' was successfully updated.")
          end

          it 'requires a number' do
            find_by_testid("seat-control-user-cap-radio").click

            expect(find(user_caps_selector).value).to eq("")

            within_testid("permissions-settings") do
              click_button 'Save changes'
            end
            expect(page).to have_content('This field is required.')

            wait_for_requests

            expect(page).not_to have_content("Group 'Foo bar' was successfully updated.")
          end

          it 'hides the required error when the user selects open access' do
            find_by_testid("seat-control-user-cap-radio").click

            expect(find(user_caps_selector).value).to eq("")

            within_testid("permissions-settings") do
              click_button 'Save changes'
            end
            expect(page).to have_content('This field is required.')
            expect(page).to have_css("#{user_caps_selector}.gl-field-error-outline")

            find_by_testid("seat-control-off-radio").click

            expect(page).not_to have_content('This field is required.')
            expect(page).not_to have_css("#{user_caps_selector}.gl-field-error-outline")
          end

          it 'disables the user cap input field when open access is selected' do
            expect(find('#group_new_user_signups_cap')).to be_disabled
          end

          it 'saves restricted access' do
            choose 'Restricted access'

            within_testid('permissions-settings') do
              click_button 'Save changes'
            end

            expect(page).to have_content("Group 'Foo bar' was successfully updated.")
            expect(page).to have_checked_field 'Restricted access'
          end

          context 'when the group cannot set a user cap or block seat overages' do
            before do
              create(:group_group_link, shared_group: group)
              visit edit_group_path(group)
            end

            it 'disables both options' do
              expect(find('#group_seat_control_block_overages')).to be_disabled
              expect(find('#group_seat_control_user_cap')).to be_disabled
              expect(find(user_caps_selector)).to be_disabled
              expect(page).to have_content 'Restricted access and user cap cannot be turned on. ' \
                'The group or one of its subgroups or projects is shared externally.'
            end
          end

          describe 'BSO warning message' do
            let(:saml_scim_warning_text) do
              'SAML/SCIM provisioning is active. ' \
                'With restricted access turned on and if no seats are available, new users provisioned through ' \
                'SAML/SCIM are assigned the non-billable Minimal Access role.'
            end

            context 'when SAML/SCIM provisioning is configured' do
              let_it_be(:saml_provider) { create(:saml_provider, group: group) }

              it 'displays the warning' do
                saml_help_path = help_page_path('user/group/saml_sso/_index.md')
                scim_help_path = help_page_path('user/group/saml_sso/scim_setup.md')

                within('#js-seat-control') do
                  expect(page).to have_link('SAML', href: saml_help_path)
                  expect(page).to have_link('SCIM', href: scim_help_path)
                  expect(page).to have_content(saml_scim_warning_text)
                end
              end
            end

            context 'when SAML/SCIM provisioning is not configured' do
              it 'does not display the warning' do
                expect(page).not_to have_content(saml_scim_warning_text)
              end
            end

            context 'when bso_minimal_access_fallback is disabled' do
              let_it_be(:saml_provider) { create(:saml_provider, group: group) }

              before do
                stub_feature_flags(bso_minimal_access_fallback: false)
                visit edit_group_path(group)
              end

              it 'does not display the warning' do
                expect(page).not_to have_content(saml_scim_warning_text)
              end
            end
          end

          context 'when contract overages are not allowed' do
            let!(:subscription) { create(:gitlab_subscription, :ultimate, namespace: group, contract_overages_allowed: false) }

            it 'explains restricted access force enablement' do
              visit edit_group_path(group)

              expect(page).to have_content('Restricted access is turned on for your subscription by default.')
              expect(page).to have_content('This setting prevents overages when no seats are available. Purchase more seats to add users.')
            end

            it 'hides seat control options' do
              visit edit_group_path(group)

              expect(page).not_to have_content('Invitations above seat count are blocked')
              expect(page).not_to have_content('Set user cap')
              expect(page).not_to have_content('Users who are added or request access beyond the user cap must be approved by a group owner.')
              expect(page).not_to have_content('Open access')
              expect(page).not_to have_content('Invitations do not need to be approved by a group owner.')
            end
          end
        end
      end
    end

    describe 'form submit button', :js do
      def fill_in_new_user_signups_cap(new_user_signups_cap_value)
        page.within('#js-permissions-settings') do
          fill_in 'group[new_user_signups_cap]', with: new_user_signups_cap_value
          click_button 'Save changes'
        end
      end

      shared_examples 'successful form submit' do
        it 'shows form submit successful message' do
          fill_in_new_user_signups_cap(new_user_signups_cap_value)

          expect(page).to have_content("Group 'Foo bar' was successfully updated.")
        end
      end

      before do
        group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: group.group_members.count)
      end

      context 'when changing seat control setting from user cap to off' do
        before do
          group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 5)
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        it 'shows a confirmation modal' do
          find_by_testid("seat-control-off-radio").click

          save_permissions_group

          expect(page).to have_selector('#confirm-general-permissions-changes')
          expect(page).to have_css('#confirm-general-permissions-changes .modal-body', text: 'By making this change, you will automatically approve all users who are pending approval.')
        end

        it 'saves the new setting' do
          find_by_testid("seat-control-off-radio").click

          save_permissions_group

          click_button 'Approve users'

          expect(page).to have_checked_field("group_seat_control_off")
        end
      end

      context 'when the auto approve pending users feature flag is enabled' do
        before do
          stub_feature_flags(saas_user_caps_auto_approve_pending_users_on_cap_increase: true)
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        context 'should show confirmation modal' do
          context 'if user cap increases' do
            let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap + 1 }

            it 'shows #confirm-general-permissions-changes modal' do
              fill_in_new_user_signups_cap(new_user_signups_cap_value)

              expect(page).to have_selector('#confirm-general-permissions-changes')
              expect(page).to have_css('#confirm-general-permissions-changes .modal-body', text: 'By making this change, you will automatically approve all users who are pending approval.')
            end
          end
        end

        context 'should not show confirmation modal' do
          context 'if user cap decreases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap - 1 }
            end
          end

          context 'if user cap changes from unlimited to limited' do
            before do
              group.namespace_settings.update!(seat_control: :off, new_user_signups_cap: nil)
              visit edit_group_path(group, anchor: 'js-permissions-settings')
            end

            it 'shows form submit successful message' do
              find_by_testid("seat-control-user-cap-radio").click

              fill_in_new_user_signups_cap(1)

              expect(page).to have_content("Group 'Foo bar' was successfully updated.")
            end
          end
        end
      end

      context 'when the auto approve pending users feature flag is disabled' do
        before do
          stub_feature_flags(saas_user_caps_auto_approve_pending_users_on_cap_increase: false)
          visit edit_group_path(group, anchor: 'js-permissions-settings')
        end

        context 'should not show confirmation modal' do
          context 'if user cap increases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap + 1 }
            end
          end

          context 'if user cap decreases' do
            it_behaves_like 'successful form submit' do
              let(:new_user_signups_cap_value) { group.namespace_settings.new_user_signups_cap - 1 }
            end
          end

          context 'if user cap changes from unlimited to limited' do
            before do
              group.namespace_settings.update!(seat_control: :off, new_user_signups_cap: nil)
              visit edit_group_path(group, anchor: 'js-permissions-settings')
            end

            it 'shows form submit successful message' do
              find_by_testid("seat-control-user-cap-radio").click

              fill_in_new_user_signups_cap(1)

              expect(page).to have_content("Group 'Foo bar' was successfully updated.")
            end
          end
        end
      end
    end
  end

  describe 'prevent project sharing setting', :saas do
    context 'when user cap is enabled' do
      before do
        group.namespace_settings.update!(seat_control: :user_cap, new_user_signups_cap: 10)
      end

      it 'forces prevent_sharing_groups_outside_hierarchy on and prevents it from being disabled' do
        visit edit_group_path(group, anchor: 'js-permissions-settings')

        expect(page).to have_checked_field('group_prevent_sharing_groups_outside_hierarchy')

        uncheck 'group_prevent_sharing_groups_outside_hierarchy'

        page.within('#js-permissions-settings') do
          click_button 'Save changes'
        end

        expect(page).to have_checked_field('group_prevent_sharing_groups_outside_hierarchy')
      end

      it 'does not force share_with_group_lock on and allows independent configuration' do
        visit edit_group_path(group, anchor: 'js-permissions-settings')

        expect(page).to have_unchecked_field('group_share_with_group_lock')

        check 'group_share_with_group_lock'

        page.within('#js-permissions-settings') do
          click_button 'Save changes'
        end

        expect(page).to have_checked_field('group_share_with_group_lock')

        uncheck 'group_share_with_group_lock'

        page.within('#js-permissions-settings') do
          click_button 'Save changes'
        end

        expect(page).to have_unchecked_field('group_share_with_group_lock')
      end
    end
  end

  describe 'Amazon Q settings' do
    let_it_be(:integration) { create(:amazon_q_integration, group: group, instance: false) }
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

    let(:amazon_q_user) { create(:user, :service_account) }
    let(:amazon_q_connected) { true }

    before do
      stub_licensed_features(amazon_q: true)
      ::Ai::Setting.for_organization(group.organization).update!(
        amazon_q_service_account_user: amazon_q_user,
        amazon_q_ready: amazon_q_connected
      )

      group.add_developer(amazon_q_user) # -- Does not work in before_all
      subproject.add_developer(amazon_q_user) # -- Does not work in before_all

      visit edit_group_path(group, anchor: 'js-amazon-q-settings')
    end

    after do
      expect_page_to_have_no_console_errors
    end

    describe 'when connected' do
      let(:amazon_q_connected) { true }

      it 'renders Amazon Q section' do
        expect(page).to have_content(_('Amazon Q'))
      end

      it 'when updates to never_on removes Amazon Q service account from members' do
        expect(group.member?(amazon_q_user)).to be_truthy
        expect(subproject.member?(amazon_q_user)).to be_truthy

        # TODO: We need to use section#id here because there's a bug in `settings_block.vue` that uses the
        # same id twice. https://gitlab.com/gitlab-org/gitlab/-/issues/510171
        within('section#js-amazon-q-settings') do
          find('input[type="radio"][value="never_on"]').click

          click_button(_('Save changes'))
        end

        expect(page).to have_content(_('Group was successfully updated.'))
        expect(group.member?(amazon_q_user)).to be_falsey
        expect(subproject.member?(amazon_q_user)).to be_falsey
      end
    end

    describe 'when not connected' do
      let(:amazon_q_connected) { false }

      it 'does not render Amazon Q section' do
        expect(page).not_to have_content(_('Amazon Q'))
      end
    end
  end

  def save_permissions_group
    within_testid('permissions-settings') do
      click_button 'Save changes'
    end
  end
end
