# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Search results for settings", :js, feature_category: :global_search, type: :feature do
  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
    allow_next_instance_of(Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive(:credits_available?).and_return(true)
    end
    allow(Gitlab::Saas).to receive(:feature_available?).and_call_original
    allow(Gitlab::Saas).to receive(:feature_available?).with(:repositories_web_based_commit_signing).and_return(true)

    stub_licensed_features(
      group_project_templates: true,
      custom_file_templates_for_namespace: true,
      pages_size_limit: true,
      protected_environments: true,
      push_rules: true,
      packages_virtual_registry: true
    )

    stub_config(dependency_proxy: { enabled: true })
  end

  it_behaves_like 'all group settings sections exist and have correct anchor links'
end
