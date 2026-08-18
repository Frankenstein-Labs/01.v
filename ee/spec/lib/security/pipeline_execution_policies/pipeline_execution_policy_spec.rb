# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::PipelineExecutionPolicy, feature_category: :security_policy_management do
  let(:policy_content) do
    {
      content: {
        include: [
          { project: 'group/compliance-project', file: 'compliance/pipeline.yml', ref: 'main' }
        ]
      },
      pipeline_config_strategy: 'inject_policy',
      suffix: 'on_conflict',
      skip_ci: {
        allowed: false,
        allowlist: {
          users: [
            { id: 1 },
            { id: 2 }
          ]
        }
      },
      variables_override: {
        allowed: false,
        exceptions: %w[VAR1 VAR2]
      }
    }
  end

  let(:scope) do
    { groups: { including: [{ id: 1 }] }, projects: { excluding: [{ id: 5 }] } }
  end

  let(:policy_record) do
    create(:security_policy, :pipeline_execution_policy,
      name: 'Test Pipeline Execution Policy',
      description: 'Test Description',
      enabled: true,
      scope: scope.as_json,
      content: policy_content)
  end

  let(:pipeline_execution_policy) { described_class.new(policy_record) }

  describe '#content' do
    subject(:content) { pipeline_execution_policy.content }

    it 'returns a Content instance with correct values' do
      expect(content).to be_a(Security::PipelineExecutionPolicies::Content)

      include_item = content.include[0]
      expect(include_item).to be_a(Security::PipelineExecutionPolicies::Include)
      expect(include_item.project).to eq('group/compliance-project')
      expect(include_item.file).to eq('compliance/pipeline.yml')
      expect(include_item.ref).to eq('main')
    end

    it 'passes the content data from policy_content' do
      expect(Security::PipelineExecutionPolicies::Content).to receive(:new).with(
        {
          include: [
            { project: 'group/compliance-project', file: 'compliance/pipeline.yml', ref: 'main' }
          ]
        }
      )

      content
    end

    context 'when content is not present in policy_content' do
      let(:policy_content) { { pipeline_config_strategy: 'inject_ci' } }

      it 'returns a content instance with default values' do
        expect(content.include).to be_empty
      end

      it 'passes an empty hash to Content' do
        expect(Security::PipelineExecutionPolicies::Content).to receive(:new).with({})

        content
      end
    end
  end

  describe '#pipeline_config_strategy' do
    subject(:pipeline_config_strategy) { pipeline_execution_policy.pipeline_config_strategy }

    context 'with valid strategies from schema' do
      %w[inject_ci inject_policy override_project_ci].each do |strategy|
        it "returns #{strategy}" do
          policy_content[:pipeline_config_strategy] = strategy
          expect(pipeline_config_strategy).to eq(strategy)
        end
      end
    end

    context 'when pipeline_config_strategy is not present' do
      let(:policy_content) { { content: { include: [{ project: 'group/project', file: 'file.yml' }] } } }

      it 'returns nil' do
        expect(pipeline_config_strategy).to be_nil
      end
    end
  end

  describe '#suffix' do
    subject(:suffix) { pipeline_execution_policy.suffix }

    context 'when suffix is on_conflict' do
      it 'returns on_conflict' do
        policy_content[:suffix] = 'on_conflict'
        expect(suffix).to eq('on_conflict')
      end
    end

    context 'when suffix is never' do
      it 'returns never' do
        policy_content[:suffix] = 'never'
        expect(suffix).to eq('never')
      end
    end

    context 'when suffix is null' do
      it 'returns nil' do
        policy_content[:suffix] = nil
        expect(suffix).to be_nil
      end
    end

    context 'when suffix is not present' do
      let(:policy_content) { { content: { include: [{ project: 'group/project', file: 'file.yml' }] } } }

      it 'returns nil' do
        expect(suffix).to be_nil
      end
    end
  end

  describe '#skip_ci' do
    subject(:skip_ci) { pipeline_execution_policy.skip_ci }

    it 'returns a SkipCi instance with correct values' do
      expect(skip_ci).to be_a(Security::PipelineExecutionPolicies::SkipCi)

      expect(skip_ci.allowed).to be false
      expect(skip_ci.allowlist_users.length).to eq(2)
      expect(skip_ci.allowlist_users.pluck(:id)).to match_array([1, 2])
    end

    it 'passes the skip_ci data from policy_content' do
      expect(Security::PipelineExecutionPolicies::SkipCi).to receive(:new).with(
        {
          allowed: false,
          allowlist: {
            users: [
              { id: 1 },
              { id: 2 }
            ]
          }
        }
      )

      skip_ci
    end

    context 'when skip_ci is not present in policy_content' do
      let(:policy_content) { { content: { include: [{ project: 'group/project', file: 'file.yml' }] } } }

      it 'returns a SkipCi instance with default values' do
        expect(skip_ci.allowed).to be_nil
        expect(skip_ci.allowlist_users).to be_empty
      end

      it 'passes an empty hash to SkipCi' do
        expect(Security::PipelineExecutionPolicies::SkipCi).to receive(:new).with({})

        skip_ci
      end
    end
  end

  describe '#variables_override' do
    subject(:variables_override) { pipeline_execution_policy.variables_override }

    it 'returns a VariablesOverride instance with correct values' do
      expect(variables_override).to be_a(Security::PipelineExecutionPolicies::VariablesOverride)

      expect(variables_override.allowed).to be false
      expect(variables_override.exceptions.length).to eq(2)
      expect(variables_override.exceptions).to match_array(%w[VAR1 VAR2])
    end

    it 'passes the variables_override data from policy_content' do
      expect(Security::PipelineExecutionPolicies::VariablesOverride).to receive(:new).with(
        {
          allowed: false,
          exceptions: %w[VAR1 VAR2]
        }
      )

      variables_override
    end

    context 'when variables_override is not present in policy_content' do
      let(:policy_content) { { content: { include: [{ project: 'group/project', file: 'file.yml' }] } } }

      it 'returns a VariablesOverride instance with default values' do
        expect(variables_override.allowed).to be_nil
        expect(variables_override.exceptions).to be_empty
      end

      it 'passes an empty hash to VariablesOverride' do
        expect(Security::PipelineExecutionPolicies::VariablesOverride).to receive(:new).with({})

        variables_override
      end
    end
  end

  describe 'inherited methods from BaseSecurityPolicy' do
    it 'delegates name to policy_record' do
      expect(pipeline_execution_policy.name).to eq('Test Pipeline Execution Policy')
    end

    it 'delegates description to policy_record' do
      expect(pipeline_execution_policy.description).to eq('Test Description')
    end

    it 'delegates enabled to policy_record' do
      expect(pipeline_execution_policy.enabled).to be true
    end

    describe '#policy_scope' do
      subject(:policy_scope) { pipeline_execution_policy.policy_scope }

      it 'returns a PolicyScope instance with correct values' do
        expect(policy_scope).to be_a(Security::PolicyScope)

        expect(policy_scope.projects).to eq({ excluding: [{ id: 5 }] })
        expect(policy_scope.groups).to eq({ including: [{ id: 1 }] })
      end

      it 'passes the policy scope data to PolicyScope' do
        expect(Security::PolicyScope).to receive(:new).with(scope)

        policy_scope
      end

      context 'when scope is not present in policy' do
        let(:scope) { {} }

        it 'returns a PolicyScope instance with default values' do
          expect(policy_scope.projects).to eq({})
          expect(policy_scope.groups).to eq({})
        end

        it 'passes an empty hash to PolicyScope' do
          expect(Security::PolicyScope).to receive(:new).with({})

          policy_scope
        end
      end
    end
  end
end
