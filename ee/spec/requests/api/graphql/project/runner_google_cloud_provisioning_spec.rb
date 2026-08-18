# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'runnerGoogleCloudProvisioning', feature_category: :runner_core do
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
  let(:inner_fragment) { query_graphql_fragment('CiRunnerGoogleCloudProvisioning') }
  let(:query) do
    graphql_query_for(
      parent_field, { fullPath: container.full_path },
      query_graphql_field(
        :runner_cloud_provisioning, { provider: :GOOGLE_CLOUD, cloud_project_id: google_cloud_project_id },
        "... on CiRunnerGoogleCloudProvisioning {
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
      let(:machine_type) { 'n2d-standard-2' }
      let(:runner_token) { runner.token }
      let(:args) do
        {
          region: region,
          zone: zone,
          ephemeral_machine_type: machine_type,
          runner_token: runner_token
        }
      end

      let(:inner_fragment) do
        query_graphql_field(:provisioning_steps, args,
          all_graphql_fields_for('CiRunnerCloudProvisioningStep'), '[CiRunnerCloudProvisioningStep!]')
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
            'instructions' => /runner_token="#{runner_token}"/,
            'languageIdentifier' => 'shell',
            'title' => 'Apply the Terraform script'
          }
        ])
      end

      context 'with nil runner token' do
        let(:runner_token) { nil }

        it 'is successful and generates a unique deployment id',
          quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/448408' do
          request
          expect_graphql_errors_to_be_empty

          expect(options_response).to match([
            a_hash_including('instructions' => /name = "grit-[A-Za-z0-9_\-]{1,8}"/),
            an_instance_of(Hash)
          ])
        end

        context 'when user does not have permissions to create runner' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(current_user, :create_runners, anything).and_return(false)
          end

          it 'returns an error' do
            request

            expect_graphql_errors_to_include(s_('Runners|The user is not allowed to create a runner'))
          end
        end
      end

      context 'with invalid runner token' do
        let(:runner_token) { 'invalid-token' }

        it 'returns an error' do
          request

          expect_graphql_errors_to_include(s_('Runners|The runner authentication token is invalid'))
        end
      end

      context 'when user cannot provision runners' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, :provision_cloud_runner, container)
            .and_return(false)
        end

        it 'returns an error' do
          request

          expect_graphql_errors_to_include("You don't have permissions to provision cloud runners")
        end
      end
    end

    context 'when user is not a maintainer or higher' do
      let(:current_user) { create(:user, developer_of: container) }

      it { is_expected.to be_nil }
    end

    context 'when SaaS feature is not enabled' do
      before do
        stub_saas_features(google_cloud_support: false)
      end

      it { is_expected.to be_nil }
    end
  end
end
