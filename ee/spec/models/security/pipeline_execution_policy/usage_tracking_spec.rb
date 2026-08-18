# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::UsageTracking, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:policy_pipelines) { [build(:pipeline_execution_policy_pipeline)] }
  let(:instance) { described_class.new(project: project, policy_pipelines: policy_pipelines) }

  describe '#track_enforcement' do
    subject(:track_enforcement) { instance.track_enforcement }

    where(:config_strategy, :variables_strategy, :expected_properties) do
      :inject_ci | nil | { label: 'inject_ci', property: 'highest_precedence', value: 1 }
      :inject_ci | { allowed: true } | { label: 'inject_ci', property: 'override_allowed', value: 1 }
      :inject_ci | { allowed: false } | { label: 'inject_ci', property: 'override_not_allowed', value: 1 }
      :inject_policy | nil | { label: 'inject_policy', property: 'highest_precedence', value: 1 }
      :inject_policy | { allowed: true } | { label: 'inject_policy', property: 'override_allowed', value: 1 }
      :inject_policy | { allowed: false } | { label: 'inject_policy', property: 'override_not_allowed', value: 1 }
      :override_project_ci | nil | { label: 'override_project_ci', property: 'highest_precedence', value: 1 }
      :override_project_ci | { allowed: true } | { label: 'override_project_ci', property: 'override_allowed',
value: 1 }
      :override_project_ci | { allowed: false } | { label: 'override_project_ci', property: 'override_not_allowed',
value: 1 }
    end

    with_them do
      let(:config) do
        build(:pipeline_execution_policy_config,
          policy: build(:pipeline_execution_policy,
            pipeline_config_strategy: config_strategy,
            variables_override: variables_strategy)
        )
      end

      let(:policy_pipelines) { [build(:pipeline_execution_policy_pipeline, policy_config: config)] }

      it 'tracks the event' do
        expect { track_enforcement }
          .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
          .with(project: project, category: described_class.name, user: nil, namespace: group, **expected_properties)
      end
    end

    context 'with multiple policy_pipelines' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }
      let(:additional_properties) { { label: 'inject_ci', property: 'highest_precedence', value: 2 } }

      it 'tracks the event' do
        expect { track_enforcement }
          .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
          .with(project: project, category: described_class.name, user: nil, namespace: group, **additional_properties)
      end

      context 'with mixed settings' do
        let(:config1) do
          build(:pipeline_execution_policy_config,
            policy: build(:pipeline_execution_policy, :inject_policy, variables_override: nil)
          )
        end

        let(:config2) do
          build(:pipeline_execution_policy_config,
            policy: build(:pipeline_execution_policy, variables_override: { allowed: true })
          )
        end

        let(:config3) do
          build(:pipeline_execution_policy_config,
            policy: build(:pipeline_execution_policy, :override_project_ci, variables_override: { allowed: false })
          )
        end

        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, policy_config: config1),
            build(:pipeline_execution_policy_pipeline, policy_config: config2),
            build(:pipeline_execution_policy_pipeline, policy_config: config3)
          ]
        end

        let(:additional_properties) { { label: 'mixed', property: 'mixed', value: 3 } }

        it 'tracks the event' do
          expect { track_enforcement }
            .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
            .with(
              project: project,
              category: described_class.name,
              user: nil,
              namespace: group,
              **additional_properties)
        end
      end
    end
  end

  describe '#track_job_execution' do
    subject(:track_job_execution) { instance.track_job_execution }

    it 'tracks the event' do
      expect { track_job_execution }
        .to trigger_internal_events('execute_job_pipeline_execution_policy')
        .with(project: project, category: described_class.name, user: nil, namespace: group)
    end
  end
end
