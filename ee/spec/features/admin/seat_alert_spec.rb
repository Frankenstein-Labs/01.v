# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin seat alert banner', :js, feature_category: :seat_cost_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:license_seats_limit) { 10 }

  let_it_be(:license) do
    create(:license, data: build(:gitlab_license, restrictions: { active_user_count: license_seats_limit }).export)
  end

  before do
    # Create enough users to reach the threshold (90% of seats)
    create_list(:user, license_seats_limit - 3)
  end

  shared_examples 'displays seat alert banner' do
    it 'shows the banner with purchase link' do
      expect(page).to have_css('.gitlab-ee-license-banner')
      expect(page).to have_link('Purchase more seats')
    end
  end

  shared_examples 'does not display seat alert banner' do
    it 'does not show the banner' do
      expect(page).not_to have_css('.gitlab-ee-license-banner')
    end
  end

  context 'when admin is logged in' do
    before do
      sign_in(admin)
      enable_admin_mode!(admin)
    end

    context 'in admin area' do
      before do
        visit admin_root_path
      end

      include_examples 'displays seat alert banner'

      context 'when banner is dismissed' do
        it 'does not show the banner' do
          find_by_testid('seat-alert-dismiss').click
          expect(page).not_to have_css('.gitlab-ee-license-banner')
          visit admin_root_path

          expect(page).not_to have_css('.gitlab-ee-license-banner')
        end
      end
    end

    context 'in regular area' do
      before do
        visit root_dashboard_path
      end

      include_examples 'does not display seat alert banner'
    end
  end

  context 'when regular user is logged in' do
    before do
      sign_in(user)
      visit root_dashboard_path
    end

    include_examples 'does not display seat alert banner'
  end

  context 'when threshold is not reached' do
    let_it_be(:license_with_high_limit) do
      create(:license, data: build(:gitlab_license, restrictions: { active_user_count: 1000 }).export)
    end

    before do
      sign_in(admin)
      enable_admin_mode!(admin)
      visit admin_root_path
    end

    include_examples 'does not display seat alert banner'
  end

  context 'without license' do
    before do
      allow(License).to receive(:current).and_return(nil)
      sign_in(admin)
      enable_admin_mode!(admin)
      visit admin_root_path
    end

    include_examples 'does not display seat alert banner'
  end
end
