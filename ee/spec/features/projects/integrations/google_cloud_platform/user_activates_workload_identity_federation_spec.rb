# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User activates Workload Identity Federation', feature_category: :system_access do
  include_context 'project integration activation'

  let(:integration) { build_stubbed(:google_cloud_platform_workload_identity_federation_integration) }

  before do
    stub_saas_features(google_cloud_support: true)
  end

  it 'activates integration', :js do
    visit_project_integration(integration.title)

    fill_in(
      s_('GoogleCloud|Project ID'),
      with: integration.workload_identity_federation_project_id)
    fill_in(
      s_('GoogleCloud|Project number'),
      with: integration.workload_identity_federation_project_number)
    fill_in(
      s_('GoogleCloud|Pool ID'),
      with: integration.workload_identity_pool_id)
    fill_in(
      s_('GoogleCloud|Provider ID'),
      with: integration.workload_identity_pool_provider_id)

    click_save_integration

    expect(page).to have_content("#{integration.title} settings saved and active.")
  end
end
