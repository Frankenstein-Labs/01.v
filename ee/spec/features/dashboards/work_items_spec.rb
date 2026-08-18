# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard work items', feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:page_path) { work_items_dashboard_path(assignee_username: [user.username]) }

  it_behaves_like 'dashboard ultimate trial callout'

  it_behaves_like 'dashboard SAML reauthentication banner' do
    let_it_be(:match_filter_params) { true }
  end
end
