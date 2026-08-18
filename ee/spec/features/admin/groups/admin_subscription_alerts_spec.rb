# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription expired notification', :js, :with_cloud_connector, feature_category: :consumables_cost_management do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  context 'for group namespace' do
    let(:group) { create(:group) }
    let!(:license) { create_current_license(plan: License::ULTIMATE_PLAN, expires_at: Date.current - 1.week) }
    let(:expected_content) { _('Your subscription expired!') }

    before do
      allow(License).to receive(:current).and_return(license)
      visit group_path(group)
    end

    it 'displays and dismisses alert' do
      expect(page).to have_content(expected_content)

      within_testid('subscribable_banner') do
        click_button('Dismiss')
      end

      visit group_path(group)

      expect(page).not_to have_content(expected_content)
    end
  end
end
