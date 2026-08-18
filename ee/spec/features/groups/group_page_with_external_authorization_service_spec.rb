# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'The group page', :js, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in user
    group.add_owner(user)
  end

  describe 'The sidebar' do
    context 'when contributions_analytics_dashboard feature flag is enabled' do
      it 'does not show the Analyze submenu' do
        visit group_path(group)

        within_testid('super-sidebar') do
          expect(page).not_to have_button 'Analyze'
        end
      end
    end

    context 'when contributions_analytics_dashboard feature flag is disabled' do
      it 'shows the link to contribution analytics' do
        stub_feature_flags(contributions_analytics_dashboard: false)
        visit group_path(group)

        within_testid('super-sidebar') do
          click_button 'Analyze'
          expect(page).to have_link('Contribution analytics')
        end
      end
    end

    context 'when epics are available' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'shows the link to work items' do
        visit group_path(group)

        within_testid('super-sidebar') do
          expect(page).to have_link('Work items')
        end
      end

      it 'hides the work items link when an external authorization service is enabled' do
        enable_external_authorization_service_check
        visit group_path(group)

        within_testid('super-sidebar') do
          expect(page).not_to have_link('Work items')
        end
      end
    end
  end
end
