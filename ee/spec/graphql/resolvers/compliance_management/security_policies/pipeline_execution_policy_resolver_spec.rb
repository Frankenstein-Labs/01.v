# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::PipelineExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let_it_be(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let_it_be(:ref_project) { create(:project, :repository) }
  let_it_be(:content) { { project: ref_project.full_path, file: 'pipeline_execution_policy.yml' } }
  let_it_be(:policy) do
    build(:pipeline_execution_policy, :variables_override_disallowed,
      name: 'Run my custom script in every pipeline',
      policy_scope: policy_scope,
      content: { include: [content] }
    )
  end

  describe '#resolve' do
    subject(:resolve_policies) do
      sync(resolve(described_class, obj: framework, args: {}, ctx: { current_user: current_user }))
    end

    context 'when user is unauthorized' do
      it 'returns an empty array' do
        expect(resolve_policies).to be_empty
      end
    end

    context 'when user is authorized' do
      let(:expected_response) do
        [
          {
            name: policy[:name],
            description: policy[:description],
            edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
              project, id: CGI.escape(policy[:name]), type: 'pipeline_execution_policy'
            ),
            policy_blob_file_path: "/#{content[:project]}/-/blob/master/#{content[:file]}",
            enabled: policy[:enabled],
            policy_scope: {
              compliance_frameworks: [framework],
              excluding_archived_projects: false,
              excluding_personal_projects: false,
              including_projects: [],
              excluding_projects: [],
              including_groups: [],
              excluding_groups: [],
              including_business_impact_attributes: [],
              excluding_business_impact_attributes: [],
              including_application_attributes: [],
              excluding_application_attributes: [],
              including_business_unit_attributes: [],
              excluding_business_unit_attributes: [],
              including_exposure_attributes: [],
              excluding_exposure_attributes: [],
              match_mode: 'all'
            },
            yaml: YAML.dump({
              name: policy[:name],
              description: policy[:description],
              enabled: policy[:enabled],
              policy_scope: policy[:policy_scope],
              pipeline_config_strategy: policy[:pipeline_config_strategy],
              content: policy[:content],
              metadata: policy[:metadata],
              suffix: policy[:suffix],
              skip_ci: policy[:skip_ci],
              variables_override: policy[:variables_override],
              no_pipeline: policy[:no_pipeline]
            }.deep_stringify_keys),
            config: policy_configuration,
            source: {
              project: project,
              namespace: nil,
              inherited: false
            },
            csp: false,
            type: 'pipeline_execution_policy',
            policy_index: 0,
            warnings: []
          }
        ]
      end

      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow(Project).to receive(:find_by_full_path).with(content[:project]).and_return(ref_project)
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return({ pipeline_execution_policy: [policy] }.to_yaml)
        end
      end

      it 'returns the policy' do
        expect(resolve_policies).to match_array(expected_response)
      end
    end
  end

  def edit_project_policy_path(target_project, policy)
    Gitlab::Routing.url_helpers.edit_project_security_policy_url(
      target_project, id: CGI.escape(policy[:name]), type: 'pipeline_execution_policy'
    )
  end
end
