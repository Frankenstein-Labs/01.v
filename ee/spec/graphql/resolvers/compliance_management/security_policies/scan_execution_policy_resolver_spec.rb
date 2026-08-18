# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::SecurityPolicies::ScanExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:framework) { create(:compliance_framework) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:compliance_framework_security_policy) do
    create(:compliance_framework_security_policy, policy_configuration: policy_configuration, framework: framework)
  end

  let_it_be(:policy_scope) { { compliance_frameworks: [{ id: framework.id }] } }
  let_it_be(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline', policy_scope: policy_scope) }

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
              project, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
            ),
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
              actions: policy[:actions],
              rules: policy[:rules],
              metadata: policy[:metadata]
            }.compact.deep_stringify_keys),
            config: policy_configuration,
            deprecated_properties: [],
            source: {
              project: project,
              namespace: nil,
              inherited: false
            },
            csp: false,
            type: 'scan_execution_policy',
            policy_index: 0
          }
        ]
      end

      before_all do
        project.add_owner(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
        end
      end

      it 'returns the policy' do
        expect(resolve_policies).to match_array(expected_response)
      end
    end
  end

  def edit_project_policy_path(target_project, policy)
    Gitlab::Routing.url_helpers.edit_project_security_policy_url(
      target_project, id: CGI.escape(policy[:name]), type: 'scan_execution_policy'
    )
  end
end
