# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates reporting settings', :js, :with_current_organization, :request_store,
  :enable_admin_mode, feature_category: :instance_resiliency do
  include Features::SettingsHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let(:license_allows) { true }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    stub_licensed_features(git_abuse_rate_limit: license_allows)
    visit reporting_admin_application_settings_path
  end

  describe 'git abuse rate limit settings' do
    context 'when license does not allow' do
      let(:license_allows) { false }

      before do
        visit reporting_admin_application_settings_path
      end

      it 'does not show the Git abuse rate limit section' do
        expect(page).not_to have_selector('[data-testid="git-abuse-rate-limit-settings"]')
      end
    end

    context 'when license allows' do
      it 'shows the Git abuse rate limit section' do
        expect(page).to have_selector('[data-testid="git-abuse-rate-limit-settings"]')
      end

      it 'shows the input fields' do
        expect(page).to have_field(s_('GitAbuse|Number of repositories'))
        expect(page).to have_field(s_('GitAbuse|Reporting time period (seconds)'))
        expect(page).to have_field(s_('GitAbuse|Excluded users'))
        expect(page).to have_selector(
          '[data-testid="auto-ban-users-toggle"] .gl-toggle-label',
          text: format(
            s_('GitAbuse|Automatically ban users from this %{scope} when they exceed the specified limits'),
            scope: 'application'
          )
        )
      end

      it 'saves the settings' do
        within_testid('git-abuse-rate-limit-settings') do
          fill_in(s_('GitAbuse|Number of repositories'), with: 5)
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: 300)
          fill_in(s_('GitAbuse|Excluded users'), with: user.name)
          expect(page).to have_button(user.name)
          click_button user.name
          within_testid('auto-ban-users-toggle') do
            find('.gl-toggle').click
          end

          click_button _('Save changes')
          wait_for_requests # rubocop:disable RSpec/AvoidWaitForRequests -- this form is saved via AJAX and there is no UI element that indicates the success
          page.refresh
        end

        expect(page).to have_field(s_('GitAbuse|Number of repositories'), with: 5)
        expect(page).to have_field(s_('GitAbuse|Reporting time period (seconds)'), with: 300)
        expect(page).to have_content(user.name)
        expect(page).to have_selector('[data-testid="auto-ban-users-toggle"] .gl-toggle.is-checked')
      end

      it 'shows form errors when the input value is blank' do
        within_testid('git-abuse-rate-limit-settings') do
          fill_in(s_('GitAbuse|Number of repositories'), with: '')
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: '')
          find('#reporting-time-period').native.send_keys :tab
        end

        expect(page).to have_content(s_("GitAbuse|Number of repositories can't be blank. Set to 0 for no limit."))
        expect(page).to have_content(s_("GitAbuse|Reporting time period can't be blank. Set to 0 for no limit."))
        expect(page).to have_button _('Save changes'), disabled: true
      end

      it 'shows form errors when the input value is greater than max' do
        page.within(find_by_testid('git-abuse-rate-limit-settings')) do
          fill_in(s_('GitAbuse|Number of repositories'), with: 10001)
          fill_in(s_('GitAbuse|Reporting time period (seconds)'), with: 864001)
          find('#reporting-time-period').native.send_keys :tab
        end

        expect(page).to have_content(
          format(s_('GitAbuse|Number of repositories should be between %{minNumRepos}-%{maxNumRepos}.'),
            minNumRepos: 0, maxNumRepos: 10000)
        )

        expect(page).to have_content(
          format(s_('GitAbuse|Reporting time period should be between %{minTimePeriod}-%{maxTimePeriod} seconds.'),
            minTimePeriod: 0, maxTimePeriod: 864000)
        )
        expect(page).to have_button _('Save changes'), disabled: true
      end
    end
  end
end
