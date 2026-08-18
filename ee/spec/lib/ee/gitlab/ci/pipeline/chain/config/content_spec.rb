# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Ci::Pipeline::Chain::Config::Content, feature_category: :continuous_integration do
  include FakeBlobHelpers

  let(:ci_config_path) { nil }
  let(:pipeline) { build(:ci_pipeline, project: project) }
  let(:content) { nil }
  let(:source) { :push }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project, origin_ref: project.default_branch_or_main,
      content: content, source: source)
  end

  let(:content_result) do
    <<~YAML
    ---
    include:
    - project: compliance/hippa
      file: ".compliance-gitlab-ci.yml"
    YAML
  end

  subject(:step) { described_class.new(pipeline, command) }

  shared_examples 'does not include compliance pipeline configuration content' do
    it 'does not include compliance pipeline configuration content' do
      step.perform!

      expect(pipeline.config_source).not_to eq 'compliance_source'
      expect(command.config_content).not_to eq(content_result)
    end
  end

  shared_examples 'does include compliance pipeline configuration content' do
    it 'does include compliance pipeline configuration content' do
      step.perform!

      expect(pipeline.config_source).to eq 'compliance_source'
      expect(command.config_content).to eq(content_result)
      expect(command.pipeline_config.internal_include_prepended?).to be(true)
    end
  end

  context 'when project has compliance label defined' do
    let(:project) { create(:project, ci_config_path: ci_config_path) }
    let(:compliance_group) { create(:group, :private, name: "compliance") }
    let(:compliance_project) { create(:project, namespace: compliance_group, name: "hippa") }

    context 'when feature is available' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
      end

      context 'when compliance pipeline configuration is defined' do
        let(:framework) do
          create(
            :compliance_framework,
            namespace: compliance_group,
            pipeline_configuration_full_path: ".compliance-gitlab-ci.yml@compliance/hippa"
          )
        end

        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'does include compliance pipeline configuration content'

        context 'when pipeline is downstream of a bridge' do
          let(:command) do
            Gitlab::Ci::Pipeline::Chain::Command.new(project: project, origin_ref: project.default_branch_or_main,
              content: content, source: source, bridge: create(:ci_bridge))
          end

          it_behaves_like 'does include compliance pipeline configuration content'

          context 'when pipeline source is parent pipeline' do
            let(:source) { :parent_pipeline }

            it_behaves_like 'does not include compliance pipeline configuration content'
          end
        end
      end

      context 'when compliance pipeline configuration is not defined' do
        let(:framework) { create(:compliance_framework, namespace: compliance_group) }
        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end

      context 'when compliance pipeline configuration is empty' do
        let(:framework) do
          create(:compliance_framework, namespace: compliance_group, pipeline_configuration_full_path: '')
        end

        let!(:framework_project_setting) do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'does not include compliance pipeline configuration content'
      end
    end

    context 'when feature is not licensed' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: false)
      end

      it_behaves_like 'does not include compliance pipeline configuration content'
    end
  end

  context 'when project does not have compliance label defined' do
    let(:project) { create(:project, ci_config_path: ci_config_path) }

    context 'when feature is available' do
      before do
        stub_licensed_features(evaluate_group_level_compliance_pipeline: true)
      end

      it_behaves_like 'does not include compliance pipeline configuration content'
    end
  end

  context 'when there are execution policy pipelines' do
    let_it_be(:project) { create(:project, :auto_devops_disabled) }
    let(:ci_config_path) { nil }

    let(:config_content_result) do
      <<~YAML
          ---
          Pipeline execution policy trigger:
            stage: ".pre"
            script:
            - echo "Forcing project pipeline to run policy jobs."
      YAML
    end

    let(:apply_config_override) { false }

    before do
      pipeline_execution_context = instance_double(
        Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
        has_execution_policy_pipelines?: true,
        applying_config_override?: apply_config_override
      )

      command.pipeline_policy_context = instance_double(
        Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext,
        pipeline_execution_context: pipeline_execution_context
      )
    end

    it 'forces the pipeline creation' do
      step.perform!

      expect(pipeline.config_source).to eq 'pipeline_execution_policy_forced'
      expect(command.config_content).to eq(config_content_result)
      expect(command.pipeline_config.internal_include_prepended?).to be(false)
    end

    context 'and a policy uses the override_project_ci strategy' do
      let_it_be(:project) { create(:project, :auto_devops_disabled) }

      let(:blob) { fake_blob(path: '.gitlab-ci.yml', data: project_content) }
      let(:apply_config_override) { true }

      let(:project_content) do
        <<~YAML
            ---
            project job:
              stage: "test"
              script:
              - echo "Run a test"
        YAML
      end

      before do
        allow(project.repository).to receive(:blob_at).with(pipeline.sha, '.gitlab-ci.yml').and_return(blob)
      end

      it 'does not include the project CI/CD configuration' do
        step.perform!

        expect(command.config_content).to eq(config_content_result)
      end

      it 'initializes Gitlab::Ci::ProjectConfig with the pipeline_policy_context option' do
        expect(Gitlab::Ci::ProjectConfig).to receive(:new).with(
          hash_including(pipeline_policy_context: anything)
        ).and_call_original

        step.perform!
      end
    end
  end
end
