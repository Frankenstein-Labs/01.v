# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat disabled admin empty state', :js, :clean_gitlab_redis_cache, :with_cloud_connector,
  feature_category: :duo_chat do
  let_it_be(:user) { create(:user, :with_namespace) }

  before do
    stub_feature_flags(duo_ui_next: false)
    stub_request(:get, "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions")
      .to_return(
        status: 200,
        body: { 'models' => [], 'unit_primitives' => [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  context 'when saas', :saas do
    let_it_be(:group) { create(:group_with_plan, plan: :premium_plan, owners: user, parent: nil) }

    include_context 'with duo features enabled and ai chat available for group on SaaS'

    before do
      group.namespace_settings.update!(duo_features_enabled: false)
      stub_licensed_features(ai_chat: true, code_suggestions: true)
      sign_in(user)
      visit group_path(group)
    end

    it 'allows group owner to enable Duo from the disabled chat state', :duo_panel_auto_expand do
      expect(page).to have_selector('[data-testid="duo-disabled-toggle"]')

      expect(page).to have_selector('[data-testid="duo-disabled-empty-state"]')

      find_by_testid('duo-settings-cta').click
      expect(page).to have_current_path(group_settings_gitlab_duo_configuration_index_path(group), ignore_query: true)

      choose 'On by default'
      click_button 'Save changes'

      expect(page).to have_selector('[data-testid="ai-chat-toggle"]')
      expect(page).to have_selector('[data-testid="ai-history-toggle"]')
      expect(page).not_to have_selector('[data-testid="duo-disabled-empty-state"]')
    end

    it 'keeps duo disabled empty panel hidden when the user hides it', :duo_panel_auto_expand do
      duo_disabled_toggle_id = 'duo-disabled-toggle'
      duo_disabled_empty_state_id = 'duo-disabled-empty-state'

      find_by_testid(duo_disabled_toggle_id).click

      expect(page).not_to have_testid(duo_disabled_empty_state_id)
      wait_for('callout dismissed') do
        Users::Callout.where(
          user_id: user.id,
          feature_name: 'duo_panel_auto_expanded'
        ).exists?
      end

      page.refresh

      expect(page).not_to have_testid(duo_disabled_empty_state_id)

      find_by_testid(duo_disabled_toggle_id).click

      expect(page).to have_testid(duo_disabled_empty_state_id)
    end
  end

  context 'when self-managed' do
    let_it_be(:group) { create(:group, owners: user) }

    include_context 'with duo features disabled and ai chat available for self-managed'
    include_context 'without ai usage quota check'

    before do
      create(:cloud_connector_keys)
      sign_in(user)
    end

    it 'allows group owner to enable Duo from the disabled chat state', :duo_panel_auto_expand do
      visit group_path(group)

      expect(page).to have_selector('[data-testid="duo-disabled-toggle"]')

      expect(page).to have_selector('[data-testid="duo-disabled-empty-state"]')

      find_by_testid('duo-settings-cta').click
      expect(page).to have_current_path(edit_group_path(group), ignore_query: true)

      within(find('section#js-gitlab-duo-settings')) do
        choose 'On by default'
        click_button 'Save changes'
      end

      expect(page).to have_selector('[data-testid="ai-chat-toggle"]')
      expect(page).to have_selector('[data-testid="ai-history-toggle"]')
      expect(page).not_to have_selector('[data-testid="duo-disabled-empty-state"]')
    end
  end
end
