# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Search results for project settings", :js, feature_category: :global_search, type: :feature do
  before do
    allow(Gitlab::Saas).to receive(:feature_available?).and_call_original
    allow(Gitlab::Saas).to receive(:feature_available?).with(:repositories_web_based_commit_signing).and_return(true)

    stub_licensed_features(
      issuable_default_templates: true,
      target_branch_rules: true,
      push_rules: true,
      merge_request_approvers: true,
      protected_environments: true,
      auto_rollback: true,
      ci_project_subscriptions: true,
      status_page: true,
      observability: true,
      ai_features: true,
      review_merge_request: true
    )
  end

  it_behaves_like 'all project settings sections exist and have correct anchor links'
end
