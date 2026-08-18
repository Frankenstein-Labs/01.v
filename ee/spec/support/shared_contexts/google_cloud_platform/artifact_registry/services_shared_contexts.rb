# frozen_string_literal: true

RSpec.shared_context 'for an artifact registry service' do
  let_it_be_with_reload(:project) { create(:project, :private) }
  let_it_be_with_refind(:artifact_registry_integration) do
    create(
      :google_cloud_platform_artifact_registry_integration,
      project: project,
      artifact_registry_project_id: 'gcp_project_id',
      artifact_registry_location: 'location',
      artifact_registry_repositories: 'repository1,repository2' # only repository1 is taken into account
    )
  end

  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let(:user) { project.owner }
  let(:params) { {} }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }
  let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }

  before do
    allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
      .with(wlif_integration: wlif_integration, user: user)
      .and_return(client_double)
  end
end
