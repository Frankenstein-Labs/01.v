# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) { execution_policies_pipeline_context.pipeline_execution_context }

  let(:sha_context) do
    Gitlab::Ci::Pipeline::ShaContext.new(
      before: command.before_sha,
      after: command.after_sha,
      source: command.source_sha,
      checkout: command.checkout_sha,
      target: command.target_sha
    )
  end

  let(:current_policy) { nil }
  let(:policy_pipelines) { [] }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: 'master', user: user) }
  let(:command_attributes) { {} }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, source: pipeline.source, current_user: user, origin_ref: pipeline.ref, **command_attributes
    )
  end

  let(:execution_policies_pipeline_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(
      project: project,
      source: command.source,
      current_user: command.current_user,
      ref: command.ref,
      sha_context: sha_context,
      variables_attributes: command.variables_attributes,
      chat_data: command.chat_data,
      merge_request: command.merge_request,
      schedule: command.schedule,
      bridge: command.bridge,
      trigger: command.trigger,
      pipeline_execution_policy_context_block: pipeline_execution_policy_context_block
    )
  end

  let(:pipeline_execution_policy_context_block) { nil }

  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policy_management_project)
  end

  let(:scheduled_policy_config) do
    build(:pipeline_execution_policy_config, :scheduled,
      policy_config: policy_configuration,
      scheduled_variables_override: { allowed: false })
  end

  shared_context 'with mocked current_policy' do
    before do
      allow(context).to receive(:current_policy).and_return(current_policy)
    end
  end

  shared_context 'with mocked policy_pipelines' do
    before do
      allow(context).to receive(:policy_pipelines).and_return(policy_pipelines)
    end
  end

  shared_context 'with mocked policy configs' do
    let(:namespace_content) { { job: { script: 'namespace script' } } }
    let(:namespace_config) do
      build(:pipeline_execution_policy_config, content: namespace_content, config_sha: 'namespace_sha')
    end

    let(:project_content) { { job: { script: 'project script' } } }
    let(:project_config) do
      build(:pipeline_execution_policy_config, :suffix_never, content: project_content, config_sha: 'project_sha')
    end

    let(:policy_configs) { [project_config, namespace_config] }

    before do
      allow_next_instance_of(::Gitlab::Security::Orchestration::ProjectPipelineExecutionPolicies) do |instance|
        allow(instance).to receive(:configs).and_return(policy_configs)
      end
    end
  end

  describe '#build_policy_pipelines!' do
    subject(:perform) { context.build_policy_pipelines!(ci_testing_partition_id) }

    include_context 'with mocked policy configs'

    it 'sets policy_pipelines' do
      perform

      expect(context.policy_pipelines).to be_a(Array)
      expect(context.policy_pipelines.size).to eq(2)
    end

    it 'passes pipeline source to policy pipelines' do
      perform

      context.policy_pipelines.each do |policy_pipeline|
        expect(policy_pipeline.pipeline.source).to eq(pipeline.source)
      end
    end

    it 'passes the right shas to the pipeline' do
      perform

      context.policy_pipelines.each do |policy_pipeline|
        expect(policy_pipeline.pipeline.ref).to eq(pipeline.ref)
        expect(policy_pipeline.pipeline.before_sha).to eq(pipeline.before_sha)
        expect(policy_pipeline.pipeline.source_sha).to eq(pipeline.source_sha)
        expect(policy_pipeline.pipeline.target_sha).to eq(pipeline.target_sha)
      end
    end

    it 'propagates partition_id to policy pipelines' do
      perform

      context.policy_pipelines.each do |policy|
        expect(policy.pipeline.partition_id).to eq(ci_testing_partition_id)
      end
    end

    it_behaves_like 'policy metrics histogram', described_class::HISTOGRAMS.fetch(:single_pipeline)
    it_behaves_like 'policy metrics histogram', described_class::HISTOGRAMS.fetch(:all_pipelines)

    context 'with variables_attributes' do
      let(:command_attributes) do
        { variables_attributes: [{ key: 'CF_STANDALONE', value: 'true', variable_type: 'env_var' }] }
      end

      it 'propagates it to policy pipelines', :aggregate_failures do
        perform

        context.policy_pipelines.each do |policy|
          variables = policy.pipeline.variables
          expect(variables).to be_one
          expect(variables.first).to have_attributes(key: 'CF_STANDALONE', value: 'true', variable_type: 'env_var')
        end
      end
    end

    context 'with merge_request parameter set on the command' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:command) do
        Gitlab::Ci::Pipeline::Chain::Command.new(
          source: pipeline.source,
          project: project,
          current_user: user,
          origin_ref: merge_request.ref_path,
          merge_request: merge_request
        )
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ when: 'always' }] } }
      end

      it 'passes the merge request to the policy pipelines' do
        perform

        context.policy_pipelines.each do |policy_pipeline|
          expect(policy_pipeline.pipeline.merge_request).to eq(merge_request)
        end
      end
    end

    context 'with trigger parameter set on the command' do
      let_it_be(:trigger) { create(:ci_trigger, project: project) }
      let(:command_attributes) { { trigger: trigger } }

      it 'passes the trigger to the policy pipelines' do
        perform

        context.policy_pipelines.each do |policy_pipeline|
          expect(policy_pipeline.pipeline.trigger).to eq(trigger)
        end
      end
    end

    context 'when a policy has strategy "override_project_ci"' do
      let(:namespace_config) do
        build(:pipeline_execution_policy_config, :override_project_ci, content: namespace_content)
      end

      it 'passes configs to policy_pipelines', :aggregate_failures do
        perform

        project_pipeline = context.policy_pipelines.first
        expect(project_pipeline.strategy_override_project_ci?).to be(false)
        expect(project_pipeline.suffix_strategy).to eq('never')
        expect(project_pipeline.suffix).to be_nil

        namespace_pipeline = context.policy_pipelines.second
        expect(namespace_pipeline.strategy_override_project_ci?).to be(true)
        expect(namespace_pipeline.suffix_strategy).to eq('on_conflict')
        expect(namespace_pipeline.suffix).to eq(':policy-123456-0')
      end
    end

    context 'when there is an error in pipeline execution policies' do
      let(:project_content) { { job: {} } }

      it 'yields the error message' do
        expect { |block| context.build_policy_pipelines!(ci_testing_partition_id, &block) }
          .to yield_with_args(a_string_including('config should implement the script'))
      end

      context 'without block' do
        it 'ignores the errored policy' do
          perform

          expect(context.policy_pipelines.size).to eq(1)
        end
      end
    end

    context 'when the policy pipeline gets filtered out by rules' do
      let(:namespace_content) do
        { job: { script: 'namespace script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }
      end

      let(:project_content) do
        { job: { script: 'project script', rules: [{ if: '$CI_COMMIT_REF_NAME == "invalid"' }] } }
      end

      before do
        perform
      end

      it 'does not add it to the policy_pipelines' do
        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'when creating_policy_pipeline? is true' do
      include_context 'with mocked current_policy'

      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it 'does not set policy_pipelines' do
        perform

        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'when pipeline execution policy configs are empty' do
      let(:policy_configs) { [] }

      it 'does not set policy_pipelines' do
        perform

        expect(context.policy_pipelines).to be_empty
      end
    end

    context 'with a dangling source' do
      Enums::Ci::Pipeline.dangling_sources.each_key do |source|
        context "when source is #{source}" do
          let(:source) { source }

          it 'does not add it to the policy_pipelines' do
            perform

            expect(context.policy_pipelines).to be_empty
          end
        end
      end

      context 'with source parent_pipeline and experiment "enforce_pipeline_policy_on_child_pipelines"' do
        let(:source) { :parent_pipeline }
        let(:command_attributes) { { bridge: bridge } }
        let(:bridge_source) { source }
        let(:bridge) do
          build_stubbed(
            :ci_bridge,
            status: :pending,
            user: user,
            job_source: build_stubbed(:ci_build_source, source: bridge_source),
            options: { trigger: { include: { local: 'child.yml' } } },
            pipeline: pipeline
          )
        end

        let(:policy_configuration) do
          build_stubbed(:security_orchestration_policy_configuration,
            experiments: { enforce_pipeline_policy_on_child_pipelines: { enabled: true } })
        end

        context 'when the experiment is enabled in one policy' do
          let(:policy_configs) do
            [
              build(:pipeline_execution_policy_config,
                policy_config: policy_configuration,
                content: namespace_content),
              build(:pipeline_execution_policy_config,
                content: project_content)
            ]
          end

          it 'adds it to the policy_pipelines' do
            perform

            expect(context.policy_pipelines).not_to be_empty
            expect(context.policy_pipelines.size).to eq(1)
          end

          context 'when the bridge was created by a policy' do
            let(:bridge_source) { 'pipeline_execution_policy' }

            it 'does not add it to the policy_pipelines' do
              perform

              expect(context.policy_pipelines).to be_empty
            end
          end
        end
      end
    end
  end

  describe '#creating_policy_pipeline?' do
    subject { context.creating_policy_pipeline? }

    include_context 'with mocked current_policy'

    it { is_expected.to be(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to be(true) }
    end
  end

  describe '#policy_management_project_access_allowed?' do
    subject { context.policy_management_project_access_allowed? }

    include_context 'with mocked current_policy'

    it { is_expected.to be(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to be(true) }
    end

    context 'when scheduled' do
      let(:command_attributes) do
        { source: ::Security::PipelineExecutionPolicies::CreateScheduledPipelineService::PIPELINE_SOURCE }
      end

      let(:current_policy) { scheduled_policy_config }

      it { is_expected.to be(true) }
    end

    context 'when child pipeline of a scheduled execution policy pipeline' do
      let(:source) { 'parent_pipeline' }
      let(:build_source) { build_stubbed(:ci_build_source, source: 'pipeline_execution_policy_schedule') }
      let(:bridge) { build_stubbed(:ci_bridge, job_source: build_source) }
      let(:command_attributes) { { bridge: bridge } }

      it { is_expected.to be(true) }
    end
  end

  describe '#creating_project_pipeline?' do
    subject { context.creating_project_pipeline? }

    include_context 'with mocked current_policy'

    it { is_expected.to be(true) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it { is_expected.to be(false) }
    end
  end

  describe '#has_execution_policy_pipelines?' do
    subject { context.has_execution_policy_pipelines? }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to be(false) }

    context 'with policy_pipelines' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it { is_expected.to be(true) }
    end
  end

  describe '#policy_pipelines_included_components' do
    subject(:result) { context.policy_pipelines_included_components }

    include_context 'with mocked policy_pipelines'

    context 'when there are no policy pipelines' do
      it { is_expected.to eq([]) }
    end

    context 'when policy pipelines have no catalog components in config_metadata' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it { is_expected.to eq([]) }
    end

    context 'when the policy pipeline config has no external includes' do
      let(:policy_pipelines) do
        [build(:pipeline_execution_policy_pipeline).tap { |pp| pp.pipeline.config_metadata = {} }]
      end

      it { is_expected.to eq([]) }
    end

    context 'when the policy pipeline config includes non-component files' do
      let(:component) { { project: build(:project), sha: 'sha1', name: 'component_a' } }

      let(:policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline).tap do |pp|
            pp.pipeline.config_metadata = {
              includes: [
                { type: :local, location: 'some/local/file.yml' },
                { type: :component, component: component }
              ]
            }
          end
        ]
      end

      it 'only returns component entries' do
        expect(result).to contain_exactly(component)
      end
    end

    context 'when policy pipelines have catalog components in config_metadata' do
      let(:component_a) { { project: build(:project), sha: 'sha1', name: 'component_a' } }
      let(:component_b) { { project: build(:project), sha: 'sha2', name: 'component_b' } }

      let(:policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline).tap do |pp|
            pp.pipeline.config_metadata = { includes: [{ type: :component, component: component_a }] }
          end,
          build(:pipeline_execution_policy_pipeline).tap do |pp|
            pp.pipeline.config_metadata = { includes: [{ type: :component, component: component_b }] }
          end
        ]
      end

      it 'returns all components from all policy pipelines' do
        expect(result).to contain_exactly(component_a, component_b)
      end
    end

    context 'when multiple policy pipelines include the same component' do
      let(:component) { { project: build(:project), sha: 'sha1', name: 'component_a' } }

      let(:policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline).tap do |pp|
            pp.pipeline.config_metadata = { includes: [{ type: :component, component: component }] }
          end,
          build(:pipeline_execution_policy_pipeline).tap do |pp|
            pp.pipeline.config_metadata = { includes: [{ type: :component, component: component }] }
          end
        ]
      end

      it 'deduplicates the components' do
        expect(result).to contain_exactly(component)
      end
    end
  end

  describe '#has_overriding_execution_policy_pipelines?' do
    subject { context.has_overriding_execution_policy_pipelines? }

    include_context 'with mocked policy configs'

    context 'without policy configs' do
      let(:policy_configs) { [] }

      it { is_expected.to be(false) }
    end

    context 'with policy configs' do
      let(:policy_configs) { [project_config, namespace_config] }

      include_context 'with mocked policy_pipelines'

      it { is_expected.to be(false) }

      context 'and at least one config having strategy override_project_ci' do
        let(:namespace_config) do
          build(:pipeline_execution_policy_config, :override_project_ci, content: namespace_content)
        end

        it { is_expected.to be(true) }

        context 'with a dangling source' do
          Enums::Ci::Pipeline.dangling_sources.each_key do |source|
            context "when source is #{source}" do
              let(:source) { source }

              it { is_expected.to be(false) }
            end
          end

          context 'with source "parent_pipeline" and experiment "enforce_pipeline_policy_on_child_pipelines"' do
            let(:source) { :parent_pipeline }
            let(:command_attributes) { { bridge: bridge } }
            let(:bridge) do
              build_stubbed(
                :ci_bridge,
                status: :pending,
                user: user,
                options: { trigger: { include: { local: 'child.yml' } } },
                pipeline: pipeline
              )
            end

            let(:policy_configuration) do
              build_stubbed(:security_orchestration_policy_configuration,
                experiments: { enforce_pipeline_policy_on_child_pipelines: { enabled: true } })
            end

            context 'when experiment is enabled on one policy' do
              let(:namespace_config) do
                build(:pipeline_execution_policy_config, :override_project_ci,
                  policy_config: policy_configuration, content: namespace_content)
              end

              it { is_expected.to be(true) }
            end
          end
        end
      end
    end
  end

  describe '#overridden_pipeline_metadata' do
    include Ci::PipelineExecutionPolicyHelpers

    subject(:overridden_pipeline_metadata) { context.overridden_pipeline_metadata }

    include_context 'with mocked policy configs'
    include_context 'with mocked policy_pipelines'
    include_context 'with mocked current_policy'

    let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }
    let(:policy_configs) { policy_pipelines.map(&:policy_config) }

    context 'without policy pipelines' do
      let(:policy_pipelines) { [] }

      it { is_expected.to eq({}) }
    end

    context 'with policy pipelines' do
      let(:policy_pipeline_with_metadata_1) do
        build_mock_policy_pipeline({ 'build' => ['docker'] }).tap do |pipeline|
          pipeline.pipeline_metadata = build(:ci_pipeline_metadata, name: 'Policy 1 name')
        end
      end

      let(:policy_pipeline_with_metadata_2) do
        build_mock_policy_pipeline({ 'test' => ['rspec'] }).tap do |pipeline|
          pipeline.pipeline_metadata = build(:ci_pipeline_metadata, name: 'Policy 2 name')
        end
      end

      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :override_project_ci) }

      it { is_expected.to eq({}) }

      context 'when at least one contains pipeline_metadata' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :override_project_ci, pipeline: policy_pipeline_with_metadata_1),
            build(:pipeline_execution_policy_pipeline, :override_project_ci)
          ]
        end

        it { is_expected.to eq(name: 'Policy 1 name') }

        context 'when creating a policy pipeline' do
          let(:current_policy) { build(:pipeline_execution_policy_config) }

          it { is_expected.to eq({}) }
        end
      end

      context 'when multiple policy pipelines contain pipeline name in metadata' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :override_project_ci, pipeline: policy_pipeline_with_metadata_1),
            build(:pipeline_execution_policy_pipeline, :override_project_ci, pipeline: policy_pipeline_with_metadata_2)
          ]
        end

        it 'uses the first one (the lowest in the hierarchy)' do
          expect(overridden_pipeline_metadata).to eq(name: 'Policy 1 name')
        end
      end

      context 'when no pipeline is override_project_ci' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, pipeline: policy_pipeline_with_metadata_1),
            build(:pipeline_execution_policy_pipeline, pipeline: policy_pipeline_with_metadata_2)
          ]
        end

        it { is_expected.to eq({}) }
      end
    end
  end

  describe '#applying_config_override?' do
    using RSpec::Parameterized::TableSyntax

    subject { context.applying_config_override? }

    where(:has_overriding_policies, :creating_project_pipeline, :expected_result) do
      true  | false | false
      true  | true | true
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(context).to receive_messages(
          has_overriding_execution_policy_pipelines?: has_overriding_policies,
          creating_project_pipeline?: creating_project_pipeline
        )
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#inject_policy_stages?' do
    subject { context.inject_policy_stages? }

    it { is_expected.to be(false) }

    context 'with current_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      include_context 'with mocked current_policy'

      it { is_expected.to be(true) }
    end

    context 'with policy_pipelines' do
      let(:policy_pipelines) { build_list(:ci_empty_pipeline, 2) }

      include_context 'with mocked policy_pipelines'

      it { is_expected.to be(true) }
    end

    context 'when scheduled' do
      let(:command_attributes) do
        { source: ::Security::PipelineExecutionPolicies::CreateScheduledPipelineService::PIPELINE_SOURCE }
      end

      let(:pipeline_execution_policy_context_block) do
        ->(args) { args.merge(current_policy: scheduled_policy_config) }
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#valid_stage?' do
    subject { context.valid_stage?(stage) }

    include_context 'with mocked current_policy'

    let(:stage) { 'test' }

    it { is_expected.to be(true) }

    %w[.pipeline-policy-pre .pipeline-policy-post].each do |stage|
      context "when stage is #{stage}" do
        let(:stage) { stage }

        it { is_expected.to be(false) }

        context 'with current_policy' do
          let(:current_policy) { build(:pipeline_execution_policy_config) }

          it { is_expected.to be(true) }
        end

        context "when scheduled" do
          let(:command_attributes) do
            { source: ::Security::PipelineExecutionPolicies::CreateScheduledPipelineService::PIPELINE_SOURCE }
          end

          let(:current_policy) { scheduled_policy_config }

          it { is_expected.to be(true) }
        end
      end
    end
  end

  describe '#collect_declared_stages!' do
    using RSpec::Parameterized::TableSyntax

    include_context 'with mocked current_policy'

    context 'with override_project_ci' do
      let(:current_policy) { build(:pipeline_execution_policy_config, :override_project_ci) }

      context 'when adding compatible stages' do
        where(:stages1, :stages2, :result) do
          []                                | %w[test]                          | %w[test]
          %w[test]                          | %w[build test]                    | %w[build test]
          %w[build test]                    | %w[test]                          | %w[build test]
          %w[build test]                    | %w[build test]                    | %w[build test]
          %w[build test deploy]             | %w[build deploy]                  | %w[build test deploy]
          %w[build test deploy]             | %w[test deploy]                   | %w[build test deploy]
          %w[build test policy-test deploy] | %w[build test deploy]             | %w[build test policy-test deploy]
          %w[policy-test]                   | %w[build test policy-test deploy] | %w[build test policy-test deploy]
        end

        with_them do
          it 'sets the largest set of stages as override_policy_stages' do
            context.collect_declared_stages!(stages1)
            context.collect_declared_stages!(stages2)

            expect(context.override_policy_stages).to eq(result)
            expect(context.injected_policy_stages).to be_empty
          end

          context 'when creating a project pipeline' do
            let(:current_policy) { nil }

            it 'does not collect the stages' do
              context.collect_declared_stages!(stages1)
              context.collect_declared_stages!(stages2)

              expect(context.override_policy_stages).to be_empty
              expect(context.injected_policy_stages).to be_empty
            end
          end
        end
      end

      context 'when adding incompatible stages' do
        where(:stages1, :stages2) do
          %w[test]              | %w[build]
          %w[build test]        | %w[test build]
          %w[build test]        | %w[test deploy]
          %w[build other]       | %w[build test deploy]
          %w[build deploy]      | %w[deploy test build]
          %w[deploy test build] | %w[build deploy]
          %w[deploy test build] | %w[build other]
          %w[deploy test]       | %w[build policy-build test policy-test deploy]
        end

        with_them do
          it 'raises an error' do
            context.collect_declared_stages!(stages1)

            expect { context.collect_declared_stages!(stages2) }
              .to raise_error(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::OverrideStagesConflictError)
          end
        end
      end
    end

    context 'with inject_ci' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it 'does not affect the resulting stages' do
        context.collect_declared_stages!(%w[build test])

        expect(context.override_policy_stages).to be_empty
        expect(context.injected_policy_stages).to be_empty
      end
    end

    context 'with inject_policy' do
      let(:current_policy) { build(:pipeline_execution_policy_config, :inject_policy) }
      let(:stages1) do
        %w[.pipeline-policy-pre .pre build test policy-test .post .pipeline-policy-post]
      end

      let(:stages2) do
        %w[.pipeline-policy-pre .pre policy-build .post .pipeline-policy-post]
      end

      it 'includes stages from all policies' do
        context.collect_declared_stages!(stages1)
        context.collect_declared_stages!(stages2)

        expect(context.override_policy_stages).to be_empty
        expect(context.injected_policy_stages).to contain_exactly(stages1, stages2)
      end

      context 'when creating a project pipeline' do
        let(:current_policy) { nil }

        it 'does not collect the stages' do
          context.collect_declared_stages!(stages1)
          context.collect_declared_stages!(stages2)

          expect(context.override_policy_stages).to be_empty
          expect(context.injected_policy_stages).to be_empty
        end
      end
    end
  end

  describe '#has_override_stages?' do
    subject { context.has_override_stages? }

    let(:stages) do
      %w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post]
    end

    context 'when no override stages are collected' do
      it { is_expected.to be(false) }
    end

    context 'with override stages' do
      before do
        allow(context).to receive(:override_policy_stages).and_return(stages)
      end

      it { is_expected.to be(true) }

      context 'when collected stages are empty' do
        let(:stages) { [] }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#has_injected_stages?' do
    subject { context.has_injected_stages? }

    let(:stages) do
      %w[.pipeline-policy-pre .pre build test policy-test .post .pipeline-policy-post]
    end

    context 'when no stages are collected' do
      it { is_expected.to be(false) }
    end

    context 'when stages are injected' do
      before do
        allow(context).to receive(:injected_policy_stages).and_return(stages)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '#force_pipeline_creation_on_empty_pipeline?' do
    subject(:force_creation) { context.force_pipeline_creation_on_empty_pipeline?(pipeline) }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to be(false) }

    context 'with policy_pipelines' do
      context 'when apply_on_empty_pipeline is an unexpected value' do
        let(:policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1, apply_on_empty_pipeline: :something_invalid)
        end

        it { is_expected.to be(true) }
      end

      context 'when apply_on_empty_pipeline is "always"' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 1, :apply_on_empty_pipeline_always) }

        it { is_expected.to be(true) }
      end

      context 'when apply_on_empty_pipeline is "never"' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 1, :apply_on_empty_pipeline_never) }

        it { is_expected.to be(false) }
      end

      context 'when apply_on_empty_pipeline is "if_no_config"' do
        let(:policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1, :apply_on_empty_pipeline_if_no_config)
        end

        context 'when project has no CI config (pipeline has no stages)' do
          before do
            allow(pipeline).to receive_messages(stages: [], pipeline_execution_policy_forced?: true)
          end

          context 'when pipeline is a merge request pipeline' do
            before do
              allow(pipeline).to receive_messages(merge_request?: true, branch?: false)
            end

            it 'forces pipeline creation' do
              expect(force_creation).to be(true)
            end
          end

          context 'when pipeline is a branch pipeline' do
            before do
              allow(pipeline).to receive_messages(merge_request?: false, branch?: true)
            end

            context 'when there are no open merge requests for the branch' do
              before do
                allow(pipeline).to receive(:open_merge_requests_refs).and_return([])
              end

              it 'forces pipeline creation' do
                expect(force_creation).to be(true)
              end
            end

            context 'when there are open merge requests for the branch' do
              before do
                allow(pipeline).to receive(:open_merge_requests_refs).and_return(['refs/merge-requests/1/head'])
              end

              it 'does not force pipeline creation to avoid duplicates' do
                expect(force_creation).to be(false)
              end
            end
          end
        end

        context 'when pipeline is not using fallback config source' do
          before do
            allow(pipeline).to receive_messages(
              stages: [],
              pipeline_execution_policy_forced?: false
            )
          end

          it 'does not force pipeline creation' do
            expect(force_creation).to be(false)
          end
        end
      end

      context 'when multiple policies have different apply_on_empty_pipeline settings' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_always),
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never)
          ]
        end

        it 'forces creation if any policy applies (always policy applies)' do
          expect(force_creation).to be(true)
        end
      end

      context 'when policies have if_no_config and always' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_always),
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_if_no_config)
          ]
        end

        it 'forces creation because always policy applies' do
          expect(force_creation).to be(true)
        end
      end

      context 'when policies have if_no_config and never' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_if_no_config),
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never)
          ]
        end

        context 'when pipeline has no CI config' do
          before do
            allow(pipeline).to receive_messages(
              stages: [],
              pipeline_execution_policy_forced?: true,
              merge_request?: true,
              branch?: false
            )
          end

          it 'forces creation because if_no_config policy applies' do
            expect(force_creation).to be(true)
          end
        end

        context 'when pipeline has CI config' do
          before do
            allow(pipeline).to receive_messages(
              stages: [],
              pipeline_execution_policy_forced?: false
            )
          end

          it 'does not force creation because neither policy applies' do
            expect(force_creation).to be(false)
          end
        end
      end

      context 'when all policies have never' do
        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never),
            build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never)
          ]
        end

        it 'does not force pipeline creation' do
          expect(force_creation).to be(false)
        end
      end

      context 'when experiment is disabled' do
        let(:policy_config_without_experiment) do
          build(:security_orchestration_policy_configuration)
        end

        let(:policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline,
              policy_config: build(:pipeline_execution_policy_config, :apply_on_empty_pipeline_never,
                policy_config: policy_config_without_experiment))
          ]
        end

        it 'ignores apply_on_empty_pipeline and forces creation (default behavior)' do
          expect(force_creation).to be(true)
        end
      end
    end
  end

  describe '#empty_pipeline_applicable_policy_pipelines' do
    subject(:applicable_pipelines) { context.empty_pipeline_applicable_policy_pipelines(pipeline) }

    include_context 'with mocked policy_pipelines'

    context 'when all policies have apply_on_empty_pipeline "always"' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :apply_on_empty_pipeline_always) }

      it 'returns all policies' do
        expect(applicable_pipelines).to eq(policy_pipelines)
      end
    end

    context 'when policies have mixed apply_on_empty_pipeline settings' do
      let(:always_policy) { build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_always) }
      let(:never_policy) { build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never) }
      let(:policy_pipelines) { [always_policy, never_policy] }

      it 'returns only the always policy' do
        expect(applicable_pipelines).to contain_exactly(always_policy)
      end
    end

    context 'when all policies have apply_on_empty_pipeline "never"' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :apply_on_empty_pipeline_never) }

      it 'returns no policies' do
        expect(applicable_pipelines).to be_empty
      end
    end

    context 'when policies have if_no_config and never' do
      let(:if_no_config_policy) do
        build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_if_no_config)
      end

      let(:never_policy) { build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never) }
      let(:policy_pipelines) { [if_no_config_policy, never_policy] }

      context 'when pipeline has no CI config' do
        before do
          allow(pipeline).to receive_messages(
            pipeline_execution_policy_forced?: true,
            merge_request?: true,
            branch?: false
          )
        end

        it 'returns only the if_no_config policy' do
          expect(applicable_pipelines).to contain_exactly(if_no_config_policy)
        end
      end

      context 'when pipeline has CI config' do
        before do
          allow(pipeline).to receive_messages(pipeline_execution_policy_forced?: false)
        end

        it 'returns no policies' do
          expect(applicable_pipelines).to be_empty
        end
      end
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed? }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to be(true) }

    context 'with policy_pipelines' do
      context 'without skip_ci specified' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

        it { is_expected.to be(false) }
      end

      context 'when all policy_pipelines allows skip_ci' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_allowed) }

        it { is_expected.to be(true) }
      end

      context 'when at least one policy_pipeline disallows skip_ci' do
        let(:policy_pipelines) do
          [
            *build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_allowed),
            *build_list(:pipeline_execution_policy_pipeline, 2, :skip_ci_disallowed)
          ]
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#no_pipeline_allowed?' do
    subject { context.no_pipeline_allowed? }

    include_context 'with mocked policy_pipelines'

    it { is_expected.to be(true) }

    context 'with policy_pipelines' do
      context 'without no_pipeline specified' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

        it { is_expected.to be(false) }
      end

      context 'when all policy_pipelines allows no_pipeline' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :no_pipeline_allowed) }

        it { is_expected.to be(true) }
      end

      context 'when at least one policy_pipeline disallows no_pipeline' do
        let(:policy_pipelines) do
          [
            *build_list(:pipeline_execution_policy_pipeline, 2, :no_pipeline_allowed),
            *build_list(:pipeline_execution_policy_pipeline, 2, :no_pipeline_disallowed)
          ]
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#job_options' do
    subject(:job_options) { context.job_options }

    include_context 'with mocked current_policy'

    context 'when building policy pipeline' do
      let(:current_policy) do
        build(:pipeline_execution_policy_config, policy_sha: 'my_policy_sha',
          policy: build(:pipeline_execution_policy, :variables_override_disallowed, name: 'My policy'))
      end

      it 'includes policy-specific options' do
        expect(job_options).to eq(
          pipeline_execution_policy_job: true,
          name: 'My policy',
          sha: 'my_policy_sha',
          project_id: current_policy.policy_config.security_policy_management_project_id,
          variables_override: { allowed: false }
        )
      end
    end

    context 'when building project pipeline' do
      it { is_expected.to be_nil }
    end

    context 'when scheduled' do
      let(:current_policy) { scheduled_policy_config }

      let(:command_attributes) do
        { source: ::Security::PipelineExecutionPolicies::CreateScheduledPipelineService::PIPELINE_SOURCE }
      end

      let(:execution_policies_pipeline_context) do
        Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(
          project: project,
          source: command.source,
          current_user: command.current_user,
          ref: command.ref,
          sha_context: sha_context,
          variables_attributes: command.variables_attributes,
          chat_data: command.chat_data,
          merge_request: command.merge_request,
          schedule: command.schedule,
          bridge: command.bridge,
          trigger: command.trigger,
          pipeline_execution_policy_context_block: ->(args) { args.merge(current_policy: scheduled_policy_config) }
        )
      end

      it 'returns scheduled policy job options' do
        expect(job_options).to include(
          pipeline_execution_policy_job: true,
          name: 'Scheduled PEP',
          variables_override: { allowed: false },
          project_id: policy_configuration.security_policy_management_project_id
        )
        expect(job_options[:sha]).to eq('policy_sha')
      end

      context 'when variables_override is not set' do
        let(:scheduled_policy_config) do
          build(:pipeline_execution_policy_config, :scheduled,
            policy_config: policy_configuration)
        end

        it 'returns job options without variables_override' do
          expect(job_options).to include(
            pipeline_execution_policy_job: true,
            name: 'Scheduled PEP',
            project_id: policy_configuration.security_policy_management_project_id
          )
          expect(job_options).not_to have_key(:variables_override)
        end
      end
    end
  end

  describe '#enforce_stages!' do
    subject(:config) { context.enforce_stages!(config: ci_config) }

    let(:default_stages) { %w[.pre build test deploy .post] }
    let(:ci_config) { Gitlab::Ci::Config.new(ci_yml, user: user).to_hash }
    let(:ci_yml) do
      YAML.dump(
        stages: %w[build test deploy],
        rspec: {
          script: 'rspec'
        }
      )
    end

    it 'does not inject the reserved stages by default' do
      expect(config[:stages]).to match_array(default_stages)
    end

    shared_examples_for 'injects reserved policy stages' do
      it 'injects reserved stages into yaml_processor_result' do
        expect(config[:stages]).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
      end

      context 'when the config already specifies reserved stages' do
        let(:ci_yml) do
          YAML.dump(
            stages: ['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'],
            rspec: {
              script: 'rspec'
            }
          )
        end

        it 'does not inject the reserved stages multiple times' do
          expect(config[:stages]).to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
        end
      end
    end

    include_context 'with mocked current_policy'
    include_context 'with mocked policy_pipelines'

    context 'when building policy pipeline' do
      let(:current_policy) { build(:pipeline_execution_policy_config) }

      it_behaves_like 'injects reserved policy stages'
    end

    context 'with policy_pipelines' do
      let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it_behaves_like 'injects reserved policy stages'

      describe 'custom policy stages' do
        let(:policy_stages) { %w[.pipeline-policy-pre .pre test policy-test deploy .post .pipeline-policy-post] }

        before do
          allow(context).to receive(:injected_policy_stages).and_return([policy_stages])
        end

        it 'injects policy stages' do
          expect(config[:stages])
            .to eq(%w[.pipeline-policy-pre .pre build test policy-test deploy .post .pipeline-policy-post])
        end

        context 'when custom stage is injected at the beginning of the pipeline' do
          let(:policy_stages) { %w[.pipeline-policy-pre policy-test .pre test] }

          it 'allows policy stages to be injected before .pre' do
            expect(config[:stages])
              .to eq(%w[.pipeline-policy-pre policy-test .pre build test deploy .post .pipeline-policy-post])
          end
        end

        context 'when the config specifies a policy stage in incorrect order' do
          let(:ci_yml) do
            YAML.dump(
              stages: %w[build policy-test test],
              rspec: {
                script: 'rspec'
              }
            )
          end

          it 'raises an error' do
            expect { config[:stages] }
              .to raise_error(Gitlab::Ci::Config::StagesMerger::InvalidStageConditionError, /Cyclic dependencies/)
          end
        end
      end

      describe 'overriding policies' do
        let(:policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :override_project_ci) }

        before do
          allow(context).to receive(:override_policy_stages)
                              .and_return(%w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post])
        end

        it 'overrides the stages' do
          expect(config[:stages])
            .to eq(%w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post])
        end

        context 'when creating a policy pipeline' do
          let(:current_policy) { build(:pipeline_execution_policy_config) }

          it 'only injects reserved stages but does not override the project stages' do
            expect(config[:stages])
              .to eq(['.pipeline-policy-pre', *default_stages, '.pipeline-policy-post'])
          end
        end
      end
    end
  end

  describe '#policy_stages_higher_precedence?' do
    subject { context.policy_stages_higher_precedence? }

    include_context 'with mocked policy configs'

    let(:policy_configuration) { build_stubbed(:security_orchestration_policy_configuration) }
    let(:policy_experiment_configuration) do
      build_stubbed(:security_orchestration_policy_configuration,
        experiments: { pipeline_execution_policy_stages_higher_precedence: { enabled: true } })
    end

    context 'without experiment enabled' do
      let(:policy_configs) do
        build_list(:pipeline_execution_policy_config, 2, policy_config: policy_configuration)
      end

      it { is_expected.to be(false) }
    end

    context 'when all policy_pipelines enable the experiment' do
      let(:policy_configs) do
        build_list(:pipeline_execution_policy_config, 2, policy_config: policy_experiment_configuration)
      end

      it { is_expected.to be(true) }
    end

    context 'when at least one policy_pipeline does not enable the experiment' do
      let(:policy_configs) do
        [
          *build_list(:pipeline_execution_policy_config, 2, policy_config: policy_experiment_configuration),
          build(:pipeline_execution_policy_config, policy_config: policy_configuration)
        ]
      end

      it { is_expected.to be(false) }
    end
  end
end
