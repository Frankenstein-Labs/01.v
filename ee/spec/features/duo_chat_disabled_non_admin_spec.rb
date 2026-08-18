# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat disabled non admin empty state', :js, :saas,
  feature_category: :duo_chat do
  include_context 'with duo features enabled and ai chat available for group on SaaS'

  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:group) { create(:group, developers: user) }

  before do
    stub_feature_flags(duo_ui_next: false)
    group.namespace_settings.update!(duo_features_enabled: false)
    sign_in(user)
    visit group_path(group)
  end

  it 'displays the non-admin empty state', :duo_panel_auto_expand do
    within_testid('duo-disabled-non-admin-empty-state') do
      expect(page).to have_content('GitLab Duo Agent Platform is turned off')
      expect(page).to have_testid('duo-learn-more')
    end
  end
end
