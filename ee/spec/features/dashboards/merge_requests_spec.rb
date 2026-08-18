# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard merge requests', feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:page_path) { merge_requests_search_dashboard_path(assignee_username: [user.username]) }

  context 'when quarantined test', quarantine: "https://gitlab.com/gitlab-org/gitlab/-/issues/512586" do
    it_behaves_like 'dashboard ultimate trial callout'
  end

  it_behaves_like 'dashboard SAML reauthentication banner' do
    let_it_be(:match_filter_params) { true }
  end
end
