# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::ComponentUsage, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let(:pipeline) { build(:ci_pipeline, project: project, partition_id: ci_testing_partition_id) }
  let_it_be_with_reload(:catalog_resource) { create(:ci_catalog_resource) }
  let_it_be_with_reload(:release) do
    create(:release, project: catalog_resource.project, tag: '1.0.0', sha: 'abc123')
  end

  let_it_be(:version) do
    create(:ci_catalog_resource_version, catalog_resource: catalog_resource, release: release, semver: release.tag)
  end

  let_it_be(:component) { create(:ci_catalog_resource_component, version: version, name: 'my_component') }
  let_it_be(:policy_component) { create(:ci_catalog_resource_component, version: version, name: 'policy_component') }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project, current_user: user, origin_ref: 'refs/heads/master')
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:project_component_hash) do
    { project: component.project, sha: version.sha, name: component.name }
  end

  let(:policy_component_hash) do
    { project: policy_component.project, sha: version.sha, name: policy_component.name }
  end

  before do
    allow(command).to receive(:yaml_processor_result)
      .and_return(instance_double(Gitlab::Ci::YamlProcessor::Result, included_components: [project_component_hash]))
  end

  describe '#perform!' do
    subject(:perform) { step.perform! }

    context 'without pipeline execution policies' do
      it 'only tracks components from the project pipeline' do
        expect(::Ci::Catalog::Resources::TrackComponentUsageWorker).to receive(:perform_async)
          .with(project.id, user.id, [
            { 'project_id' => component.project.id, 'sha' => version.sha, 'name' => component.name }
          ])

        perform
      end
    end

    context 'with pipeline execution policies that include catalog components' do
      let(:pipeline_execution_context) do
        instance_double(
          Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
          policy_pipelines_included_components: [policy_component_hash]
        )
      end

      let(:pipeline_policy_context) do
        instance_double(
          Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
          pipeline_execution_context: pipeline_execution_context
        )
      end

      before do
        allow(command).to receive(:pipeline_policy_context).and_return(pipeline_policy_context)
      end

      it 'tracks components from both the project pipeline and policy pipelines' do
        expect(::Ci::Catalog::Resources::TrackComponentUsageWorker).to receive(:perform_async)
          .with(project.id, user.id, containing_exactly(
            { 'project_id' => component.project.id, 'sha' => version.sha, 'name' => component.name },
            { 'project_id' => policy_component.project.id, 'sha' => version.sha, 'name' => policy_component.name }
          ))

        perform
      end

      context 'when the same component appears in both the project and policy pipeline' do
        let(:pipeline_execution_context) do
          instance_double(
            Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
            policy_pipelines_included_components: [project_component_hash]
          )
        end

        it 'deduplicates and only tracks the component once' do
          expect(::Ci::Catalog::Resources::TrackComponentUsageWorker).to receive(:perform_async)
            .with(project.id, user.id, [
              { 'project_id' => component.project.id, 'sha' => version.sha, 'name' => component.name }
            ])

          perform
        end
      end

      context 'when the policy pipeline has no catalog components' do
        let(:pipeline_execution_context) do
          instance_double(
            Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
            policy_pipelines_included_components: []
          )
        end

        it 'only tracks components from the project pipeline' do
          expect(::Ci::Catalog::Resources::TrackComponentUsageWorker).to receive(:perform_async)
            .with(project.id, user.id, [
              { 'project_id' => component.project.id, 'sha' => version.sha, 'name' => component.name }
            ])

          perform
        end
      end
    end
  end
end
