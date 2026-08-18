# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User activates Artifact Management', :js, :sidekiq_inline, feature_category: :container_registry do
  include_context 'project integration activation'

  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group, projects: [project], parent: parent_group) }

  let(:integration) { build_stubbed(:google_cloud_platform_artifact_registry_integration) }
  let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }

  before_all do
    parent_group.add_owner(user)
  end

  before do
    stub_saas_features(google_cloud_support: true)

    allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
      .with(wlif_integration: an_instance_of(::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation),
        user: user)
      .and_return(client_double)
    allow(client_double).to receive(:repository)
      .and_return(dummy_repository_response)
  end

  subject(:visit_page) { visit_project_integration('Google Artifact Management') }

  shared_examples 'activates integration' do
    it 'activates integration' do
      visit_page

      expect(page).not_to have_link('View artifacts')

      expect(page).to be_axe_clean.within_testid('integration-settings-form')
        .skipping :'link-in-text-block', :'color-contrast'

      fill_in s_('GoogleCloud|Google Cloud project ID'),
        with: integration.artifact_registry_project_id
      fill_in s_('GoogleCloud|Repository location'),
        with: integration.artifact_registry_location
      fill_in s_('GoogleCloud|Repository name'),
        with: integration.artifact_registry_repositories

      click_save_integration

      expect(page).to have_content('Google Artifact Management settings saved and active.')

      expect(page).to have_link('View artifacts',
        href: project_google_cloud_artifact_registry_index_path(project))

      expect(page).to be_axe_clean.within_testid('integration-settings-form')
        .skipping :'link-in-text-block', :'color-contrast'
    end
  end

  shared_examples 'tests saved integration' do
    it 'saves, activates and tests the saved integration' do
      visit_page

      fill_in s_('GoogleCloud|Google Cloud project ID'),
        with: integration.artifact_registry_project_id
      fill_in s_('GoogleCloud|Repository location'),
        with: integration.artifact_registry_location
      fill_in s_('GoogleCloud|Repository name'),
        with: integration.artifact_registry_repositories

      click_save_integration

      expect(page).to have_content('Google Artifact Management settings saved and active.')

      click_test_integration

      expect(page).to have_content('Connection successful.')

      expect(page).to be_axe_clean.within_testid('integration-settings-form')
        .skipping :'link-in-text-block', :'color-contrast'
    end
  end

  shared_examples 'inactive integration' do
    it 'shows empty state & links to iam integration page' do
      visit_page

      expect(page).to have_link('Set up Google Cloud IAM',
        href: edit_project_settings_integration_path(project, :google_cloud_platform_workload_identity_federation))
      expect(page).to have_button('Invite member to set up')
    end
  end

  context 'when the iam integration is not active' do
    it_behaves_like 'inactive integration'
  end

  context 'with an active iam integration in the root group' do
    let_it_be(:root_group_integration) do
      create(:google_cloud_platform_workload_identity_federation_integration, project: nil, group: parent_group)
    end

    before do
      ::Integrations::PropagateService.new(root_group_integration).execute
    end

    it_behaves_like 'activates integration'
    it_behaves_like 'tests saved integration'

    context 'and inactive at project level' do
      before do
        project.google_cloud_platform_workload_identity_federation_integration.update_column(:active, false)
      end

      it_behaves_like 'inactive integration'
    end
  end

  private

  def dummy_repository_response
    ::Google::Cloud::ArtifactRegistry::V1::Repository.new(name: 'test')
  end
end
