# frozen_string_literal: true

RSpec.shared_context 'for a compute service' do
  let_it_be_with_reload(:project) { create(:project, :private) }
  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let(:user) { create(:user, owner_of: project) }
  let(:client_double) { instance_double('::GoogleCloud::Compute::Client') }
  let(:service) { described_class.new(container: project, current_user: user, params: params) }

  let(:google_cloud_project_id) { nil }
  let(:google_cloud_support) { false }

  before do
    stub_saas_features(google_cloud_support: google_cloud_support)

    allow(::GoogleCloud::Compute::Client).to receive(:new)
      .with(
        wlif_integration: wlif_integration,
        user: user,
        params: { google_cloud_project_id: google_cloud_project_id }.compact
      ).and_return(client_double)
  end
end
