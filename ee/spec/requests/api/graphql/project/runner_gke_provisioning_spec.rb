# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RunnerGkeProvisioning', feature_category: :runner_core do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:group_owner) { create(:user, owner_of: group) }
  let_it_be_with_refind(:group_wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: nil, group: group)
  end

  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:project_maintainer) { create(:user, maintainer_of: group) }
  let_it_be_with_refind(:project_wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let(:google_cloud_project_id) { 'project-id-override' }
  let(:inner_fragment) { query_graphql_fragment('CiRunnerGkeProvisioning') }
  let(:query) do
    graphql_query_for(
      parent_field, { fullPath: container.full_path },
      query_graphql_field(
        :runner_cloud_provisioning, { provider: :GKE, cloud_project_id: google_cloud_project_id },
        "... on CiRunnerGkeProvisioning {
          #{inner_fragment}
        }"
      )
    )
  end

  let(:options_response) do
    request
    graphql_data_at(GraphqlHelpers.fieldnamerize(parent_field), 'runnerCloudProvisioning')
  end

  subject(:request) do
    post_graphql(query, current_user: current_user)
  end

  before do
    stub_saas_features(google_cloud_support: true)
  end

  where(:parent_field, :container, :current_user) do
    :group   | ref(:group)   | ref(:group_owner)
    :project | ref(:project) | ref(:project_maintainer)
  end

  with_them do
    context 'when cloud_project_id is invalid' do
      let(:google_cloud_project_id) { 'project_id_override' }

      it 'returns an error' do
        request

        expect_graphql_errors_to_include('"project_id_override" is not a valid project name')
      end
    end

    describe 'projectSetupShellScript' do
      let(:inner_fragment) { 'projectSetupShellScript' }
      let(:options_response) do
        request

        graphql_data_at(
          GraphqlHelpers.fieldnamerize(parent_field), 'runnerCloudProvisioning', 'projectSetupShellScript')
      end

      it 'returns a script' do
        request
        expect_graphql_errors_to_be_empty

        expect(options_response).to be_a(String)
        expect(options_response).to include google_cloud_project_id
      end
    end

    describe 'provisioningSteps' do
      let_it_be(:runner) { create(:ci_runner, :project, projects: [project], token: 'v__x-zPvFbogsYEgaCq-') }

      let(:region) { 'us-central1' }
      let(:zone) { 'us-central1-a' }
      let(:runner_token) { runner.token }
      let(:args) do
        {
          region: region,
          zone: zone,
          runner_token: runner_token
        }
      end

      let(:inner_fragment) do
        query_graphql_field(:provisioning_steps, args,
          all_graphql_fields_for('CiRunnerGkeProvisioningStep'), '[CiRunnerGkeProvisioningStep!]')
      end

      let(:options_response) do
        request
        graphql_data_at(GraphqlHelpers.fieldnamerize(parent_field), 'runnerCloudProvisioning', 'provisioningSteps')
      end

      it 'returns provisioning steps', :aggregate_failures do
        request
        expect_graphql_errors_to_be_empty

        expect(options_response).to match([
          {
            'instructions' => /google_project += "#{google_cloud_project_id}"/,
            'languageIdentifier' => 'terraform',
            'title' => 'Save the Terraform script to a file'
          },
          {
            'instructions' => /runner_token.*#{runner_token}/,
            'languageIdentifier' => 'shell',
            'title' => 'Apply the Terraform script'
          }
        ])
      end

      context 'when user cannot provision runners' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, :provision_gke_runner, container)
            .and_return(false)
        end

        it 'returns null' do
          request

          expect(options_response).to be_nil
        end
      end
    end
  end
end
