# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::PipelineExecutionPolicyResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  include_context 'orchestration policy context'

  let_it_be(:ref_project) { create(:project, :repository) }
  let(:content) { { project: ref_project.full_path, file: 'pipeline_execution_policy.yml' } }
  let(:project_full_path) { content[:project] }
  let(:policy) do
    build(:pipeline_execution_policy, :variables_override_disallowed,
      name: 'Run custom pipeline', content: { include: [content] })
  end

  let(:policy_yaml) { build(:orchestration_policy_yaml, pipeline_execution_policy: [policy]) }
  let(:expected_resolved) do
    [
      {
        name: 'Run custom pipeline',
        description: 'This policy enforces execution of custom CI in the pipeline',
        edit_path: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
          project, id: CGI.escape(policy[:name]), type: 'pipeline_execution_policy'
        ),
        policy_blob_file_path: "/#{content[:project]}/-/blob/master/#{content[:file]}",
        enabled: true,
        policy_scope: {
          compliance_frameworks: [],
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
        policy_index: 0,
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
        type: "pipeline_execution_policy",
        source: {
          inherited: false,
          namespace: nil,
          project: project
        },
        warnings: []
      }
    ]
  end

  before do
    allow(Project).to receive(:find_by_full_path).with(project_full_path).and_return(ref_project)
  end

  subject(:resolve_policies) { resolve(described_class, obj: project, ctx: { current_user: user }) }

  it_behaves_like 'as an orchestration policy' do
    describe 'policy_blob_file_path' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        project.add_developer(user)
      end

      context 'when ref is included in the content' do
        let(:content) { { project: ref_project.full_path, file: 'pipeline_execution.yml', ref: 'v1.0.0' } }

        it 'returns a file path' do
          expect(resolve_policies[0][:policy_blob_file_path]).to eq(
            "/#{content[:project]}/-/blob/#{content[:ref]}/#{content[:file]}"
          )
        end

        it 'does not include warning message' do
          expect(resolve_policies[0][:warnings]).to be_empty
        end
      end

      context 'when referenced project does not exist' do
        before do
          allow(Project).to receive(:find_by_full_path).with(content[:project]).and_return(nil)
        end

        let(:content) { { project: 'not_existing_project', file: 'not-existing.yml', ref: 'v1.0.0' } }

        it 'returns an empty string' do
          expect(resolve_policies[0][:policy_blob_file_path]).to eq("")
        end

        it 'includes warning message' do
          expect(resolve_policies[0][:warnings]).to include(
            'The policy is associated with a non-existing pipeline configuration file.')
        end
      end

      context 'when filtering by inherited policies' do
        let(:project_full_path) { ref_project.full_path }
        let(:args) { { relationship: :inherited } }

        subject(:resolve_policies) do
          resolve(described_class, obj: project, ctx: { current_user: user }, args: args,
            arg_style: :internal)
        end

        context 'when policy does not contains content' do
          let(:content) { nil }

          it 'returns an empty string' do
            expect(resolve_policies[0][:policy_blob_file_path]).to eq("")
          end

          it 'includes warning message' do
            expect(resolve_policies[0][:warnings]).to include(
              'The policy is associated with a non-existing pipeline configuration file.')
          end
        end
      end
    end
  end
end
