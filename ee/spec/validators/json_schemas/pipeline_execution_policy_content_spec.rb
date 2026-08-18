# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'pipeline_execution_policy_content.json', feature_category: :security_policy_management do
  let(:schema_path) do
    Rails.root.join("ee/app/validators/json_schemas/pipeline_execution_policy_content.json")
  end

  let(:schema) { JSONSchemer.schema(schema_path) }
  let(:base_policy) do
    {
      content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] }
    }
  end

  describe 'pipeline_config_strategy' do
    context 'with string format' do
      context 'with valid strategy' do
        %w[inject_ci inject_policy override_project_ci].each do |strategy|
          it "accepts #{strategy}" do
            policy = base_policy.merge(pipeline_config_strategy: strategy)
            expect(schema.valid?(policy)).to be true
          end
        end
      end

      context 'with invalid strategy' do
        it 'rejects unknown strategy' do
          policy = base_policy.merge(pipeline_config_strategy: 'invalid_strategy')
          expect(schema.valid?(policy)).to be false
        end
      end
    end

    context 'with object format' do
      context 'with valid type and apply_on_empty_pipeline' do
        it 'accepts inject_policy with apply_on_empty_pipeline always' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_policy', apply_on_empty_pipeline: 'always' }
          )
          expect(schema.valid?(policy)).to be true
        end

        it 'accepts inject_policy with apply_on_empty_pipeline if_no_config' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_policy', apply_on_empty_pipeline: 'if_no_config' }
          )
          expect(schema.valid?(policy)).to be true
        end

        it 'accepts inject_policy with apply_on_empty_pipeline never' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_policy', apply_on_empty_pipeline: 'never' }
          )
          expect(schema.valid?(policy)).to be true
        end

        it 'accepts inject_ci with apply_on_empty_pipeline' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_ci', apply_on_empty_pipeline: 'if_no_config' }
          )
          expect(schema.valid?(policy)).to be true
        end

        it 'accepts override_project_ci with apply_on_empty_pipeline' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'override_project_ci', apply_on_empty_pipeline: 'never' }
          )
          expect(schema.valid?(policy)).to be true
        end
      end

      context 'with type only (no apply_on_empty_pipeline)' do
        it 'accepts type without apply_on_empty_pipeline' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_policy' }
          )
          expect(schema.valid?(policy)).to be true
        end
      end

      context 'with invalid values' do
        it 'rejects invalid type' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'invalid_type', apply_on_empty_pipeline: 'always' }
          )
          expect(schema.valid?(policy)).to be false
        end

        it 'rejects invalid apply_on_empty_pipeline' do
          policy = base_policy.merge(
            pipeline_config_strategy: { type: 'inject_policy', apply_on_empty_pipeline: 'invalid_behaviour' }
          )
          expect(schema.valid?(policy)).to be false
        end

        it 'rejects object without type' do
          policy = base_policy.merge(
            pipeline_config_strategy: { apply_on_empty_pipeline: 'always' }
          )
          expect(schema.valid?(policy)).to be false
        end

        it 'rejects object with additional properties' do
          policy = base_policy.merge(
            pipeline_config_strategy: {
              type: 'inject_policy', apply_on_empty_pipeline: 'always', extra: 'value'
            }
          )
          expect(schema.valid?(policy)).to be false
        end
      end
    end
  end

  describe 'suffix' do
    context 'with valid values' do
      it 'accepts on_conflict' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', suffix: 'on_conflict')
        expect(schema.valid?(policy)).to be true
      end

      it 'accepts never' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', suffix: 'never')
        expect(schema.valid?(policy)).to be true
      end

      it 'accepts null' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', suffix: nil)
        expect(schema.valid?(policy)).to be true
      end
    end

    context 'with invalid values' do
      it 'rejects invalid suffix' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', suffix: 'invalid')
        expect(schema.valid?(policy)).to be false
      end
    end
  end

  describe 'skip_ci' do
    context 'with valid configuration' do
      it 'accepts allowed: true' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', skip_ci: { allowed: true })
        expect(schema.valid?(policy)).to be true
      end

      it 'accepts allowed: false with allowlist' do
        policy = base_policy.merge(
          pipeline_config_strategy: 'inject_ci',
          skip_ci: { allowed: false, allowlist: { users: [{ id: 123 }] } }
        )
        expect(schema.valid?(policy)).to be true
      end
    end

    context 'with invalid configuration' do
      it 'rejects skip_ci without allowed' do
        policy = base_policy.merge(pipeline_config_strategy: 'inject_ci', skip_ci: { allowlist: {} })
        expect(schema.valid?(policy)).to be false
      end
    end
  end

  describe 'variables_override' do
    context 'with valid configuration' do
      it 'accepts allowed: true' do
        policy = base_policy.merge(
          pipeline_config_strategy: 'inject_ci',
          variables_override: { allowed: true }
        )
        expect(schema.valid?(policy)).to be true
      end

      it 'accepts allowed: false with exceptions' do
        policy = base_policy.merge(
          pipeline_config_strategy: 'inject_ci',
          variables_override: { allowed: false, exceptions: %w[VAR1 VAR2] }
        )
        expect(schema.valid?(policy)).to be true
      end
    end

    context 'with invalid configuration' do
      it 'rejects variables_override without allowed' do
        policy = base_policy.merge(
          pipeline_config_strategy: 'inject_ci',
          variables_override: { exceptions: %w[VAR1] }
        )
        expect(schema.valid?(policy)).to be false
      end
    end
  end
end
