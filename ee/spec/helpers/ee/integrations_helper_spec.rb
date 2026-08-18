# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe EE::IntegrationsHelper, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  let_it_be(:organization) { create(:common_organization) }
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }

  describe '#integration_form_data' do
    context 'when integration is at the project level' do
      let(:integration) { build(:jenkins_integration) }

      let(:jira_fields) do
        {
          show_jira_issues_integration: 'false',
          show_jira_vulnerabilities_integration: 'false',
          enable_jira_issues: 'true',
          enable_jira_vulnerabilities: 'false',
          project_key: 'FE',
          project_keys: 'FE,BE',
          vulnerabilities_issuetype: '10001',
          customize_jira_issue_enabled: 'false'
        }
      end

      subject(:form_data) { helper.integration_form_data(integration, project: project) }

      it 'does not include Jira-specific fields' do
        is_expected.not_to include(*jira_fields.keys)
      end

      context 'with a Jira integration' do
        let_it_be_with_refind(:integration) { create(:jira_integration, project: project, issues_enabled: true, project_key: 'FE', project_keys: %w[FE BE], vulnerabilities_enabled: true, vulnerabilities_issuetype: '10001', customize_jira_issue_enabled: false) }

        context 'when there is no license for jira_vulnerabilities_integration' do
          before do
            allow(integration).to receive(:jira_vulnerabilities_integration_available?).and_return(false)
          end

          it 'includes default Jira fields' do
            is_expected.to include(jira_fields)
          end
        end

        context 'when all flags are enabled' do
          before do
            stub_licensed_features(jira_issues_integration: true, jira_vulnerabilities_integration: true)
          end

          it 'includes all Jira fields' do
            is_expected.to include(
              jira_fields.merge(
                show_jira_issues_integration: 'true',
                show_jira_vulnerabilities_integration: 'true',
                enable_jira_vulnerabilities: 'true'
              )
            )
          end
        end
      end

      context 'with Google Artifact Registry integration' do
        let_it_be_with_refind(:integration) { create(:google_cloud_platform_artifact_registry_integration, project: project) }

        shared_examples 'active iam integration' do
          it 'is editable' do
            is_expected.to include(editable: 'true')
          end

          it 'does not include workload_identity_federation_path field' do
            is_expected.not_to include(:workload_identity_federation_path)
          end

          it 'includes wlif fields' do
            is_expected.to include(
              workload_identity_federation_project_number: project.google_cloud_platform_workload_identity_federation_integration.workload_identity_federation_project_number,
              workload_identity_pool_id: project.google_cloud_platform_workload_identity_federation_integration.workload_identity_pool_id
            )
          end
        end

        shared_examples 'inactive iam integration' do
          it 'is not-editable' do
            is_expected.to include(editable: 'false')
          end

          it 'includes workload_identity_federation_path field' do
            is_expected.to include(
              workload_identity_federation_path: edit_project_settings_integration_path(project, :google_cloud_platform_workload_identity_federation)
            )
          end

          it 'does not includes wlif fields' do
            is_expected.not_to include(
              :workload_identity_federation_project_number,
              :workload_identity_pool_id
            )
          end
        end

        it 'includes Google Artifact Registry fields' do
          is_expected.to include(
            artifact_registry_path: project_google_cloud_artifact_registry_index_path(project),
            operating: 'true'
          )
        end

        context 'when Google Cloud IAM integration does not exist' do
          it_behaves_like 'inactive iam integration'
        end

        context 'with active Google Cloud IAM integration' do
          before do
            create(:google_cloud_platform_workload_identity_federation_integration, project: project)
          end

          it_behaves_like 'active iam integration'
        end

        context 'with inactive Google Cloud IAM integration' do
          before do
            create(:google_cloud_platform_workload_identity_federation_integration, project: project, active: false)
          end

          it_behaves_like 'inactive iam integration'
        end
      end

      context 'with Google Cloud IAM integration' do
        let_it_be_with_refind(:integration) { create(:google_cloud_platform_workload_identity_federation_integration, project: project) }

        it 'include wlif_issuer field' do
          is_expected.to include(
            wlif_issuer: ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.wlif_issuer_url(project),
            jwt_claims: ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.jwt_claim_mapping_script_value
          )
        end
      end
    end

    context 'when integration is at the group level' do
      let(:integration) { build(:google_cloud_platform_workload_identity_federation_integration, group: group) }

      subject(:form_data) { helper.integration_form_data(integration, group: group) }

      context 'with Google Cloud IAM integration' do
        it 'include wlif_issuer field' do
          is_expected.to include(
            wlif_issuer: ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.wlif_issuer_url(group),
            jwt_claims: ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.jwt_claim_mapping_script_value
          )
        end
      end
    end

    context 'when integration is at the instance level' do
      let_it_be(:integration) { create(:amazon_q_integration) }

      subject(:form_data) { helper.integration_form_data(build(:amazon_q_integration)) }

      context 'with Amazon Q integration' do
        before do
          stub_current_organization(organization)
          ::Ai::Setting.for_organization(organization).update!(
            amazon_q_ready: true,
            amazon_q_role_arn: 'role-arn'
          )
        end

        it 'returns the data related to amazon q' do
          identity_provider_params = {
            instance_uid: 'instance_uid',
            aws_provider_url: "https://auth.token.gitlab.com/cc/oidc/instance_uid",
            aws_audience: "gitlab-cc-instance_uid"
          }

          expect_next_instance_of(::Ai::AmazonQ::IdentityProviderPayloadFactory) do |instance|
            expect(instance).to receive(:execute).and_return({ ok: identity_provider_params })
          end

          is_expected.to include({
            amazon_q: {
              submit_url: admin_ai_amazon_q_settings_path,
              disconnect_url: disconnect_admin_ai_amazon_q_settings_path,
              ready: "true",
              role_arn: "role-arn",
              availability: :default_on,
              auto_review_enabled: "false"
            }.merge(identity_provider_params)
          })

          expect(flash[:alert]).to be_nil
        end

        it 'adds an error to flash if identity provider factory fails' do
          expect_next_instance_of(::Ai::AmazonQ::IdentityProviderPayloadFactory) do |instance|
            expect(instance).to receive(:execute).and_return({ err: { message: 'failure' } })
          end

          amazon_q_data(integration)

          expect(flash[:alert]).to eq('Something went wrong retrieving the identity provider payload. failure')
        end
      end
    end
  end

  describe '#integrations_allow_list_data' do
    let_it_be(:allow_all_integrations) { false }
    let_it_be(:allowed_integrations) { ['jira'] }
    let_it_be(:application_setting) do
      build_stubbed(:application_setting, integrations: {
        allow_all_integrations: allow_all_integrations, allowed_integrations: allowed_integrations
      })
    end

    subject(:allow_list_data) { helper.integrations_allow_list_data }

    before do
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'includes integrations list as JSON' do
      integrations = Gitlab::Json.parse(allow_list_data[:integrations])

      expect(integrations).to be_an_instance_of(Array)
      expect(integrations).to include(
        { 'title' => 'Slack notifications', 'name' => 'slack' }
      )
    end

    it 'includes setting values' do
      is_expected.to include(
        allow_all_integrations: 'false',
        allowed_integrations: '["jira"]'
      )
    end
  end

  describe '#jira_issues_show_data' do
    subject { helper.jira_issues_show_data }

    before do
      allow(helper).to receive(:params).and_return({ id: 'FE-1' })
      assign(:project, project)
    end

    it 'includes Jira issues show data' do
      is_expected.to include(
        issues_show_path: "/#{project.full_path}/-/integrations/jira/issues/FE-1.json",
        issues_list_path: "/#{project.full_path}/-/integrations/jira/issues"
      )
    end
  end

  describe '#external_issue_breadcrumb_title' do
    let(:expected_title) { 'my-ref' }

    subject { helper.external_issue_breadcrumb_title(issue_reference) }

    context 'with a valid issue_reference' do
      let(:issue_reference) { 'my-ref' }

      it 'returns the correct HTML' do
        is_expected.to eq(expected_title)
      end
    end

    context 'when issue_reference contains HTML' do
      let(:issue_reference) { "<script>alert('XSS')</script>my-ref" }

      it 'strips all tags' do
        is_expected.to eq(expected_title)
      end
    end
  end

  describe '#zentao_issue_breadcrumb_link' do
    subject { helper.zentao_issue_breadcrumb_link(issue_json) }

    context 'with valid issue JSON' do
      let(:issue_json) { { id: "my-ref", web_url: "https://example.com" } }

      it 'returns the correct HTML' do
        is_expected.to eq('<img width="15" height="15" class="gl-mr-2 lazy" data-src="/assets/logos/zentao-91a4a40cfe1a1640cb4fcf645db75e0ce23fbb9984f649c0675e616d6ff8c632.svg" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" /><a target="_blank" rel="noopener noreferrer" class="gl-flex gl-items-center gl-whitespace-nowrap" href="https://example.com">my-ref</a>')
      end
    end

    context 'when issue_reference contains XSS' do
      let(:issue_json) { { id: "<script>alert('XSS')</script>my-ref", web_url: "javascript:alert('XSS')" } }

      it 'strips all tags and sanitizes' do
        is_expected.to eq('<img width="15" height="15" class="gl-mr-2 lazy" data-src="/assets/logos/zentao-91a4a40cfe1a1640cb4fcf645db75e0ce23fbb9984f649c0675e616d6ff8c632.svg" src="data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" /><a target="_blank" rel="noopener noreferrer" class="gl-flex gl-items-center gl-whitespace-nowrap">my-ref</a>')
      end
    end
  end
end
