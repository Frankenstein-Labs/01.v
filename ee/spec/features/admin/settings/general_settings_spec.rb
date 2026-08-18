# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates general settings', :with_current_organization, :request_store, :enable_admin_mode,
  feature_category: :system_access do
  include Features::SettingsHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  describe 'external authentication', feature_category: :system_access do
    before do
      visit general_admin_application_settings_path
    end

    it 'enables external authentication', :aggregate_failures do
      within_testid('external-auth-settings') do
        click_unchecked_field s_('ExternalAuthorization|Enable classification control using an external service')
        fill_field_with_new_value s_('ExternalAuthorization|Default classification label'), 'default'

        expect_save_settings

        expect_field_checked s_('ExternalAuthorization|Enable classification control using an external service')
        expect_field_value s_('ExternalAuthorization|Default classification label'), 'default'
      end
    end
  end

  describe 'LDAP settings', feature_category: :system_access do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(ldap_setting)

      visit general_admin_application_settings_path
    end

    context 'with LDAP enabled' do
      let(:ldap_setting) { true }

      it 'changes to allow group owners to manage ldap' do
        within_testid('admin-visibility-access-settings') do
          click_checked_field _('Allow group owners to manage LDAP-related settings')

          expect_save_settings

          expect_field_unchecked _('Allow group owners to manage LDAP-related settings')
        end
      end
    end

    context 'with LDAP disabled' do
      let(:ldap_setting) { false }

      it 'does not show option to allow group owners to manage ldap' do
        expect(page).not_to have_css('#application_setting_allow_group_owners_to_manage_ldap')
      end
    end
  end

  describe 'disableable EE-only features', feature_category: :system_access do
    using RSpec::Parameterized::TableSyntax

    where(:feature_name, :field_id, :selector, :label) do
      :disable_personal_access_tokens |
        '#application_setting_disable_personal_access_tokens' |
        'account-and-limit-settings-content' |
        lazy { s_('AccessTokens|Disable access tokens') }
      :disable_invite_members |
        '#application_setting_disable_invite_members' |
        'admin-visibility-access-settings' |
        lazy { _('Disable inviting new members to group or project by group/project owners or project maintainers') }
    end

    with_them do
      context 'when the feature is not licensed' do
        before do
          stub_licensed_features(feature_name => false)
          visit general_admin_application_settings_path
        end

        it 'does not show the setting' do
          expect(page).not_to have_css(field_id)
        end
      end

      context 'when the feature is licensed' do
        before do
          current_settings.update_attribute(feature_name, true)
          visit general_admin_application_settings_path
        end

        it 'enables the setting' do
          within_testid(selector) do
            click_checked_field label

            expect_save_settings

            expect_field_unchecked label
          end
        end
      end
    end
  end

  describe 'sign up settings', :js, feature_category: :user_profile do
    it 'changes the user cap from unlimited to 5' do
      visit general_admin_application_settings_path

      expect(current_settings.new_user_signups_cap).to be_nil

      within('#js-signup-settings') do
        find_by_testid('seat-control-user-cap').click
        fill_field_with_new_value _('Set user cap'), '5'

        expect_save_settings

        expect_field_value _('Set user cap'), '5'
      end
    end

    context 'with a user cap assigned' do
      let(:seat_control_user_cap) { 1 }

      before do
        current_settings.update!(new_user_signups_cap: 5, seat_control: seat_control_user_cap)
      end

      context 'with no pending users' do
        before do
          visit general_admin_application_settings_path
        end

        it 'changes the user cap to unlimited' do
          within('#js-signup-settings') do
            fill_in 'application_setting[new_user_signups_cap]', with: nil
            find_by_testid("seat-control-open-access").click

            expect_save_settings
          end

          expect(current_settings.new_user_signups_cap).to be_nil
        end
      end

      context 'with pending users' do
        before do
          create(:user, :blocked_pending_approval)
          visit general_admin_application_settings_path
        end

        it 'displays a modal confirmation when removing the cap' do
          page.within('#js-signup-settings') do
            fill_field_with_new_value _('Set user cap'), ''
            find_by_testid("seat-control-open-access").click

            click_button s_('ApplicationSettings|Save changes')
          end

          page.within('.modal') do
            click_button 'Proceed and approve 1 user'
          end

          # Wait for the form POST to redirect (URL gains a `#js-signup-settings` fragment)
          # before asserting DB state, otherwise the read races the write.
          expect(page).to have_current_path(/#js-signup-settings/, url: true)
          expect(current_settings.new_user_signups_cap).to be_nil
        end
      end

      context 'with form submit button confirmation modal for side-effect of possibly having overages' do
        let_it_be(:license) do
          create(:license, plan: License::ULTIMATE_PLAN, restrictions: { active_user_count: 9 })
        end

        before do
          allow(License).to receive(:current).and_return(license)

          visit general_admin_application_settings_path
        end

        describe 'when user cap is higher than licensed users' do
          it 'shows a modal' do
            within_testid('sign-up-restrictions-settings-content') do
              fill_field_with_new_value _('Set user cap'), '13'

              click_button s_('ApplicationSettings|Save changes')
            end

            within_modal do
              expect(page).to have_content "Changing the user cap to 13 would exceed the licensed user " \
                "count of 9, which may result in seat overages"
            end
          end
        end

        describe 'when user cap is lower than licensed users' do
          it 'submits the form' do
            within_testid('sign-up-restrictions-settings-content') do
              fill_field_with_new_value _('Set user cap'), '3'

              expect_save_settings

              expect_field_value _('Set user cap'), '3'
            end
          end
        end
      end
    end

    context 'for form submit button confirmation modal for side-effect of possibly adding unwanted new users' do
      using RSpec::Parameterized::TableSyntax

      where(:require_admin_approval_action, :user_cap_action, :add_pending_user, :button_effect) do
        :unchanged_true  | :unchanged                         | false | :submits_form
        :unchanged_false | :unchanged                         | false | :submits_form
        :toggled_off     | :unchanged                         | true  | :shows_confirmation_modal
        :toggled_off     | :unchanged                         | false | :submits_form
        :toggled_on      | :unchanged                         | false | :submits_form
        :unchanged_false | :increased                         | true  | :shows_confirmation_modal
        :unchanged_true  | :increased                         | false | :submits_form
        :toggled_off     | :increased                         | true  | :shows_confirmation_modal
        :toggled_off     | :increased                         | false | :submits_form
        :toggled_on      | :increased                         | true  | :shows_confirmation_modal
        :toggled_on      | :increased                         | false | :submits_form
        :toggled_on      | :decreased                         | false | :submits_form
        :toggled_on      | :decreased                         | true  | :submits_form
        :unchanged_false | :changed_from_limited_to_unlimited | true  | :shows_confirmation_modal
        :unchanged_false | :changed_from_limited_to_unlimited | false | :submits_form
        :unchanged_false | :changed_from_unlimited_to_limited | false | :submits_form
        :unchanged_false | :unchanged_unlimited               | false | :submits_form
      end

      with_them do
        it "handles form submission appropriately based on settings configuration" do
          user_cap_default = 5
          seat_control_user_cap = 1
          require_admin_approval_value = [:unchanged_true, :toggled_off].include?(require_admin_approval_action)

          current_settings.update_attribute(:require_admin_approval_after_user_signup, require_admin_approval_value)

          # rubocop:disable RSpec/AvoidConditionalStatements -- keeping the logic for readability
          unless [:changed_from_unlimited_to_limited, :unchanged_unlimited].include?(user_cap_action)
            current_settings.update!(new_user_signups_cap: user_cap_default, seat_control: seat_control_user_cap)
          end

          create(:user, :blocked_pending_approval) if add_pending_user
          # rubocop:enable RSpec/AvoidConditionalStatements

          visit general_admin_application_settings_path

          page.within('#js-signup-settings') do
            case require_admin_approval_action
            when :toggled_on
              find_by_testid('require-admin-approval-checkbox').set(true)
            when :toggled_off
              find_by_testid('require-admin-approval-checkbox').set(false)
            end

            case user_cap_action
            when :increased
              fill_field_with_new_value _('Set user cap'), (user_cap_default + 1).to_s
            when :decreased
              fill_field_with_new_value _('Set user cap'), (user_cap_default - 1).to_s
            when :changed_from_limited_to_unlimited
              fill_field_with_new_value _('Set user cap'), ''
              find_by_testid("seat-control-open-access").click
            when :changed_from_unlimited_to_limited
              find_by_testid('seat-control-user-cap').click
              fill_field_with_new_value _('Set user cap'), user_cap_default.to_s
            end
          end

          case button_effect
          when :shows_confirmation_modal
            page.within('#js-signup-settings') do
              click_button s_('ApplicationSettings|Save changes')
            end
            expect(page).to have_selector('.modal')
            expect(page).to have_css('.modal .modal-body',
              text: 'By changing this setting, you can also automatically approve 1 user who is pending approval.')
          when :submits_form
            within('#js-signup-settings') { expect_save_settings }
          end
        end
      end
    end
  end

  describe 'SCIM token', feature_category: :system_access do
    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(instance_level_scim: false)
        visit general_admin_application_settings_path
      end

      it 'does not display the section when not licensed' do
        expect(page).not_to have_content(s_('SCIM|SCIM Token'))
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(instance_level_scim: true)
        visit general_admin_application_settings_path
      end

      it 'displays the section', :js, :aggregate_failures do
        expect(page).to have_content(s_('SCIM|SCIM Token'))

        click_button s_('GroupSAML|Generate a SCIM token')
        expect(page).to have_content s_('GroupSaml|Your SCIM token')
        expect(page).to have_content s_('GroupSaml|SCIM API endpoint URL')
      end
    end
  end

  describe 'SCIM token restricted access warning', feature_category: :system_access do
    before do
      stub_licensed_features(instance_level_scim: true)
    end

    context 'when restricted access is enabled' do
      before do
        stub_ee_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
      end

      it 'shows a restricted access warning' do
        visit general_admin_application_settings_path

        expect(page).to have_content(s_('GroupSAML|Restricted access is active'))
        expect(page).to have_content('With restricted access active and no seats available')
      end

      context 'when bso_minimal_access_fallback is disabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: false)

          visit general_admin_application_settings_path
        end

        it 'does not show a restricted access warning' do
          expect(page).not_to have_content(s_('GroupSAML|Restricted access is active'))
        end
      end
    end

    context 'when restricted access is disabled' do
      before do
        visit general_admin_application_settings_path
      end

      it 'does not show a restricted access warning in the SCIM section' do
        expect(page).to have_content(s_('SCIM|SCIM Token'))
        expect(page).not_to have_content(s_('GroupSAML|Restricted access is active'))
      end
    end
  end

  describe 'Microsoft Azure integration', feature_category: :system_access do
    before do
      allow(::Gitlab::Auth::Saml::Config).to receive(:microsoft_group_sync_enabled?).and_return(true)
    end

    it_behaves_like 'Microsoft Azure integration form' do
      let(:path) { general_admin_application_settings_path }
    end
  end

  def current_settings
    ApplicationSetting.current_without_cache || Gitlab::CurrentSettings.current_application_settings
  end
end
