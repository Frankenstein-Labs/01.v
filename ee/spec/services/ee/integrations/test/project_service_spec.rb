# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe ::Integrations::Test::ProjectService, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  describe '#execute' do
    let_it_be(:project) { create(:project) }

    let(:user) { project.first_owner }
    let(:event) { nil }
    let(:sample_data) { { data: 'sample' } }
    let(:success_result) { { success: true, result: {} } }

    subject(:result) { described_class.new(integration, user, event).execute }

    context 'without event specified' do
      context 'GitHubService' do
        let_it_be(:integration) { create(:github_integration, project: project) }

        it_behaves_like 'tests for integration with pipeline data'
      end

      context 'with Integrations::GoogleCloudPlatform::ArtifactRegistry' do
        let_it_be(:integration) { create(:google_cloud_platform_artifact_registry_integration, project: project) }

        let_it_be(:wlif_integration) do
          create(:google_cloud_platform_workload_identity_federation_integration, project: project)
        end

        let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }

        before do
          stub_saas_features(google_cloud_support: true)

          allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
            .with(wlif_integration: wlif_integration, user: user).and_return(client_double)

          allow(client_double).to receive(:repository)
            .and_return(dummy_repository_response)
        end

        it 'tests the integration with default data' do
          expect(result).to eq(success: true, result: nil)
        end

        private

        def dummy_repository_response
          ::Google::Cloud::ArtifactRegistry::V1::Repository.new(name: 'test')
        end
      end
    end
  end
end
