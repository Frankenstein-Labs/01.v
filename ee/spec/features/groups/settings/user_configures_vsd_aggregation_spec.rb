# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Analytics > User configures VSD aggregation', :js, feature_category: :value_stream_management do
  include ListboxHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: subgroup) }
  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  before do
    sign_in(user)
  end

  context 'without correct license' do
    before do
      stub_licensed_features(group_level_analytics_dashboard: false)

      visit group_settings_analytics_path(group)
    end

    it 'does not show the VSD config' do
      expect(page).not_to have_selector('[data-testid="value-streams-dashboards-settings"]')
    end
  end

  context 'with correct license' do
    before do
      stub_licensed_features(group_level_analytics_dashboard: true)
    end

    context 'when visiting top-level group settings page' do
      before do
        visit group_settings_analytics_path(group)
      end

      it 'allows to enable the aggregation' do
        checkbox_text = s_('GroupSettings|Enable overview background aggregation for Value Streams Dashboard')
        checkbox = 'group_value_stream_dashboard_aggregation_attributes_enabled'

        within_testid('value-streams-dashboards-settings') do
          page.check(checkbox_text)

          page.click_button _('Save changes')
        end

        expect(page).to have_checked_field(checkbox)

        aggregation = Analytics::ValueStreamDashboard::Aggregation.find_by(namespace_id: group.id)
        expect(aggregation).to be_present
        expect(aggregation).to be_enabled
      end
    end

    context 'when developer visiting the settings page' do
      before do
        sign_in(developer)
      end

      it 'renders 404 not found' do
        visit group_settings_analytics_path(group)

        expect(page).to have_content('Page not found')
      end
    end

    context 'when visiting subgroup settings page' do
      before do
        visit group_settings_analytics_path(subgroup)
      end

      it 'does not show the VSD config' do
        expect(page).not_to have_selector('[data-testid="value-streams-dashboards-settings"]')
      end
    end
  end
end
