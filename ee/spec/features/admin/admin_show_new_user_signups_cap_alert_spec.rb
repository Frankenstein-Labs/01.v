# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'displays new user signups cap alert', :js, feature_category: :acquisition do
  let_it_be(:admin) { create(:admin) }

  let(:help_page_href) { help_page_path('administration/settings/sign_up_restrictions.md') }
  let(:expected_content) { 'Your instance has reached its user cap' }

  context 'when reached active users cap', :do_not_mock_admin_mode_setting do
    before do
      stub_application_setting(new_user_signups_cap: 1)
      stub_feature_flags(hide_incident_management_features: false)
      stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)

      sign_in(admin)
      visit root_path
    end

    it 'displays and dismiss alert' do
      expect(page).to have_content(expected_content)
      expect(page).to have_link('usage caps', href: help_page_href)

      visit root_dashboard_path
      find('.js-new-user-signups-cap-reached .gl-dismiss-btn').click

      expect(page).not_to have_content(expected_content)
      expect(page).not_to have_link('usage caps', href: help_page_href)
    end
  end
end
