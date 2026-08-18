# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::ApplyPolicies, feature_category: :security_policy_management do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, project: project, ref: 'master', user: user) }

  let(:execution_policy_pipelines) do
    [
      build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'build' => ['docker'] })),
      build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
    ]
  end

  let(:policy_configs) { execution_policy_pipelines.map(&:policy_config) }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref
    )
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:config) do
    { build_job: { stage: 'build', script: 'docker build .' },
      rake: { stage: 'test', script: 'rake' } }
  end

  subject(:run_chain) do
    run_previous_chain(pipeline, command)
    perform_chain(pipeline, command)
  end

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(config)) if config
    allow(command.pipeline_policy_context.pipeline_execution_context)
      .to receive_messages(policies: policy_configs, policy_pipelines: execution_policy_pipelines)
  end

  describe '#perform!' do
    it 'reassigns jobs to the correct stage', :aggregate_failures do
      run_chain

      build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
      expect(build_stage.statuses.map(&:name)).to contain_exactly('build_job', 'docker')

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
    end

    describe 'tracking' do
      let(:additional_properties) { { label: 'inject_ci', property: 'highest_precedence', value: 2 } }
      let(:category) { Security::PipelineExecutionPolicy::UsageTracking.name }

      it 'tracks the event' do
        expect { run_chain }
          .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
          .with(project: project, category: category, user: nil, namespace: group, **additional_properties)
      end
    end

    context 'with conflicting jobs' do
      let(:conflicting_job_script) { 'echo "job with suffix"' }
      let(:non_conflicting_job_script) { 'echo "job without suffix"' }

      shared_examples_for 'merges both jobs using suffix for conflicts' do |job_name|
        it 'keeps both jobs, appending suffix to the conflicting job name', :aggregate_failures do
          run_chain

          test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
          expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec', "#{job_name}:policy-123456-0")

          first_policy_rspec_job = test_stage.statuses.find { |status| status.name == 'rspec' }
          expect(first_policy_rspec_job.options[:script]).to eq non_conflicting_job_script

          second_policy_rspec_job = test_stage.statuses.find { |status| status.name == "#{job_name}:policy-123456-0" }
          expect(second_policy_rspec_job.options[:script]).to eq conflicting_job_script
        end

        it 'does not break the processing chain' do
          run_chain

          expect(step.break?).to be false
        end
      end

      shared_examples_for 'results in duplicate job error' do |job_name|
        it 'results in duplicate job error' do
          run_chain

          expect(pipeline.errors[:base])
            .to contain_exactly("Pipeline execution policy error: job names must be unique (#{job_name})")
        end

        it 'breaks the processing chain' do
          run_chain

          expect(step.break?).to be true
        end

        it 'increments a counter metric' do
          expect(command).to receive(:increment_duplicate_job_name_errors_counter).with('never')

          run_chain
        end
      end

      context 'when two policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: non_conflicting_job_script),
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: conflicting_job_script)
          ]
        end

        it_behaves_like 'merges both jobs using suffix for conflicts', 'rspec'

        context 'when jobs contain `needs`' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'], 'deploy' => ['check-needs-rspec'] }),
                job_script: non_conflicting_job_script),
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline(
                  { 'test' => %w[rspec jest], 'deploy' => %w[check-needs-rspec coverage-needs-jest] }
                ),
                job_script: conflicting_job_script)
            ]
          end

          before do
            policy1_stages = execution_policy_pipelines.first.pipeline.stages
            policy1_rspec = policy1_stages.first.statuses.find { |job| job.name == 'rspec' }
            build_job_needs(job: policy1_stages.last.statuses.first, needs: policy1_rspec)

            policy2_stages = execution_policy_pipelines.last.pipeline.stages
            policy2_rspec = policy2_stages.first.statuses.find { |job| job.name == 'rspec' }
            policy2_jest = policy2_stages.first.statuses.find { |job| job.name == 'jest' }
            build_job_needs(job: policy2_stages.last.statuses.first, needs: policy2_rspec)
            build_job_needs(job: policy2_stages.last.statuses.last, needs: policy2_jest)
          end

          it 'updates references in job `needs` per policy pipeline', :aggregate_failures do
            run_chain

            expect(get_stage_jobs(pipeline, 'test'))
              .to contain_exactly('rake', 'rspec', 'rspec:policy-123456-0', 'jest')
            expect(get_stage_jobs(pipeline, 'deploy'))
              .to contain_exactly('check-needs-rspec', 'check-needs-rspec:policy-123456-0', 'coverage-needs-jest')

            expect(get_job_needs(pipeline, 'deploy', 'check-needs-rspec')).to contain_exactly('rspec')
            expect(get_job_needs(pipeline, 'deploy', 'check-needs-rspec:policy-123456-0'))
              .to contain_exactly('rspec:policy-123456-0')
            expect(get_job_needs(pipeline, 'deploy', 'coverage-needs-jest')).to contain_exactly('jest')
          end
        end

        context 'when suffix is set to "never"' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] })),
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
            ]
          end

          it_behaves_like 'results in duplicate job error', 'rspec'
        end
      end

      context 'when project and policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] }),
              job_script: conflicting_job_script),
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: non_conflicting_job_script)
          ]
        end

        it_behaves_like 'merges both jobs using suffix for conflicts', 'rake'

        context 'when suffix is set to "never"' do
          context 'when a policy with duplicate job uses "never" suffix' do
            let(:execution_policy_pipelines) do
              [
                build(:pipeline_execution_policy_pipeline, :suffix_never,
                  pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] })),
                build(:pipeline_execution_policy_pipeline,
                  pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
              ]
            end

            it_behaves_like 'results in duplicate job error', 'rake'
          end
        end

        context 'when other policy uses "never" strategy' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] }), job_script: conflicting_job_script),
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }), job_script: non_conflicting_job_script)
            ]
          end

          it_behaves_like 'merges both jobs using suffix for conflicts', 'rake'
        end
      end
    end

    context 'when policy defines additional stages' do
      context 'when custom policy stage is also defined but not used in the main pipeline' do
        let(:config) do
          { stages: %w[build test custom],
            rake: { stage: 'test', script: 'rake' } }
        end

        let(:execution_policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1,
            pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
        end

        it 'injects the policy job into the custom stage', :aggregate_failures do
          run_chain

          expect(pipeline.stages.map(&:name)).to contain_exactly('test', 'custom')

          custom_stage = pipeline.stages.find { |stage| stage.name == 'custom' }
          expect(custom_stage.position).to eq(4)
          expect(custom_stage.statuses.map(&:name)).to contain_exactly('docker')
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { 'execute_job_pipeline_execution_policy' }
          let(:category) { Security::PipelineExecutionPolicy::UsageTracking.name }
          let_it_be(:project) { project }
          let_it_be(:user) { nil }
          let_it_be(:namespace) { project.group }
        end

        context 'when the policy has multiple jobs' do
          let(:execution_policy_pipelines) do
            build_list(:pipeline_execution_policy_pipeline, 1,
              pipeline: build_mock_policy_pipeline({ 'custom' => %w[docker rspec] }))
          end

          it 'triggers one event per job' do
            expect { run_chain }.to trigger_internal_events('execute_job_pipeline_execution_policy')
                                    .with(category: Security::PipelineExecutionPolicy::UsageTracking.name,
                                      project: project,
                                      namespace:  project.group)
                                    .exactly(2).times
          end
        end
      end

      context 'when custom policy stage is not defined in the main pipeline' do
        let(:execution_policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1,
            pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
        end

        it 'ignores the stage' do
          run_chain

          expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
        end

        it_behaves_like 'internal event not tracked' do
          let(:event) { 'execute_job_pipeline_execution_policy' }
        end
      end
    end

    context 'when the policy stage is defined in a different position than the stage in the main pipeline' do
      let(:config) do
        { stages: %w[build test],
          rake: { stage: 'test', script: 'rake' } }
      end

      let(:execution_policy_pipelines) do
        build_list(:pipeline_execution_policy_pipeline, 1,
          pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
      end

      it 'reassigns the position and stage_idx for the jobs to match the main pipeline', :aggregate_failures do
        run_chain

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.position).to eq(3)
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
        expect(test_stage.statuses.map(&:stage_idx)).to all(eq(test_stage.position))
      end
    end

    context 'when there are gaps in the main pipeline stages due to them being unused' do
      let(:config) do
        { stages: %w[build test deploy],
          package: { stage: 'deploy', script: 'package' } }
      end

      let(:execution_policy_pipelines) do
        build_list(:pipeline_execution_policy_pipeline, 1,
          pipeline: build_mock_policy_pipeline({ 'deploy' => ['docker'] }))
      end

      it 'reassigns the position and stage_idx for policy jobs based on the declared stages', :aggregate_failures do
        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('deploy')

        deploy_stage = pipeline.stages.find { |stage| stage.name == 'deploy' }
        expect(deploy_stage.position).to eq(4)
        expect(deploy_stage.statuses.map(&:name)).to contain_exactly('package', 'docker')
        expect(deploy_stage.statuses.map(&:stage_idx)).to all(eq(deploy_stage.position))
      end
    end

    context 'when there is no project CI configuration' do
      let(:config) { nil }

      let(:category) { Security::PipelineExecutionPolicy::UsageTracking.name }
      let(:additional_properties) { { label: 'inject_ci', property: 'highest_precedence', value: 2 } }

      it 'removes the dummy job that forced the pipeline creation and only keeps policy jobs in default stages' do
        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')

        build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
        expect(build_stage.statuses.map(&:name)).to contain_exactly('docker')

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rspec')
      end

      it 'tracks the event' do
        expect { run_chain }
          .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
          .with(project: project, category: category, user: nil, namespace: group, **additional_properties)
      end
    end

    context 'when a policy has strategy "override_project_ci"' do
      let(:config) do
        { rake: { script: 'rake' } }
      end

      let(:execution_policy_pipelines) do
        [
          build(
            :pipeline_execution_policy_pipeline, :override_project_ci,
            pipeline: build_mock_policy_pipeline({ '.pipeline-policy-pre' => ['rspec'] })
          )
        ]
      end

      let(:additional_properties) { { label: 'override_project_ci', property: 'highest_precedence', value: 1 } }
      let(:category_name) { Security::PipelineExecutionPolicy::UsageTracking.name }

      it 'clears the project CI and injects the policy jobs' do
        run_chain

        expect(pipeline.stages).to be_one
        pre_stage = pipeline.stages.find { |stage| stage.name == '.pipeline-policy-pre' }
        expect(pre_stage.statuses.map(&:name)).to contain_exactly('rspec')
      end

      context 'with custom override policy stages' do
        let(:execution_policy_pipelines) do
          [
            build(
              :pipeline_execution_policy_pipeline, :override_project_ci,
              pipeline: build_mock_policy_pipeline({ 'policy-test' => ['rspec'] })
            )
          ]
        end

        before do
          allow(command.pipeline_policy_context.pipeline_execution_context)
            .to receive(:override_policy_stages)
                  .and_return(%w[.pipeline-policy-pre .pre policy-test .post .pipeline-policy-post])
        end

        it 'uses override_policy_stages to inject jobs' do
          run_chain

          expect(pipeline.stages).to be_one
          policy_test_stage = pipeline.stages.find { |stage| stage.name == 'policy-test' }
          expect(policy_test_stage.statuses.map(&:name)).to contain_exactly('rspec')
        end
      end

      it 'tracks the event' do
        expect { run_chain }
          .to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
          .with(project: project, category: category_name, user: nil, namespace: group, **additional_properties)
      end
    end

    context 'when execution_policy_pipelines is not defined' do
      let(:execution_policy_pipelines) { [] }

      it 'does not change pipeline stages' do
        expect { run_chain }.not_to change { pipeline.stages }
      end

      it 'does not tracks the event' do
        expect { run_chain }
          .not_to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
      end
    end

    context 'when pipeline creation was forced to continue (empty pipeline scenario)' do
      let(:config) { nil }

      let(:always_policy_pipeline) do
        build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_always,
          pipeline: build_mock_policy_pipeline({ 'build' => ['always_job'] }))
      end

      let(:never_policy_pipeline) do
        build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never,
          pipeline: build_mock_policy_pipeline({ 'test' => ['never_job'] }))
      end

      let(:execution_policy_pipelines) { [always_policy_pipeline, never_policy_pipeline] }

      before do
        command.pipeline_creation_forced_to_continue = true
        allow(command.pipeline_policy_context.pipeline_execution_context)
          .to receive(:empty_pipeline_applicable_policy_pipelines)
          .with(pipeline)
          .and_return([always_policy_pipeline])
      end

      it 'only applies policy pipelines that should apply based on their apply_on_empty_pipeline setting',
        :aggregate_failures do
        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('build')

        build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
        expect(build_stage.statuses.map(&:name)).to contain_exactly('always_job')
      end

      it 'tracks only the applicable policy pipelines' do
        expect(Security::PipelineExecutionPolicy::UsageTracking)
          .to receive(:new)
          .with(project: project, policy_pipelines: [always_policy_pipeline])
          .and_call_original

        run_chain
      end
    end

    context 'when pipeline creation was not forced (non-empty pipeline scenario)' do
      let(:execution_policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline, :apply_on_empty_pipeline_never,
            pipeline: build_mock_policy_pipeline({ 'build' => ['policy_job'] }))
        ]
      end

      before do
        command.pipeline_creation_forced_to_continue = false
      end

      it 'applies all policy pipelines regardless of apply_on_empty_pipeline setting', :aggregate_failures do
        run_chain

        build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
        expect(build_stage.statuses.map(&:name)).to include('policy_job')
      end
    end

    context 'when project and policy pipelines have overlapping job_name_mappings' do
      let(:project_mappings) do
        { build: ['build 1/2', 'build 2/2'] }
      end

      let(:execution_policy_pipelines) do
        [
          build(:pipeline_execution_policy_pipeline,
            pipeline: build_mock_policy_pipeline({ 'build' => ['docker'] }),
            job_name_mappings: { build: ['build 1/2', 'build 2/2'], lint: ['lint 1/2', 'lint 2/2'] }),
          build(:pipeline_execution_policy_pipeline,
            pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
            job_name_mappings: { lint: ['lint 1/2', 'lint 2/2'] })
        ]
      end

      before do
        run_previous_chain(pipeline, command)
        allow(command.yaml_processor_result).to receive(:job_name_mappings).and_return(project_mappings)
      end

      it 'deduplicates names when the same key appears in multiple mappings', :aggregate_failures do
        combined = step.send(:combined_job_name_mappings)

        expect(combined[:build]).to contain_exactly('build 1/2', 'build 2/2')
        expect(combined[:lint]).to contain_exactly('lint 1/2', 'lint 2/2')
      end
    end

    context 'when creating_policy_pipeline? is true' do
      let(:config) do
        { stages: %w[test policy-test],
          policy_test_job: { stage: 'policy-test', script: 'echo "policy-test"' },
          test_job: { stage: 'test', script: 'echo "test"' } }
      end

      let(:execution_policy_config) { build(:pipeline_execution_policy_config) }

      before do
        allow(command.pipeline_policy_context.pipeline_execution_context)
          .to receive(:current_policy).and_return(execution_policy_config)
      end

      it 'does not change pipeline stages' do
        expect { run_chain }.not_to change { pipeline.stages }
      end

      context 'with "inject_ci" policy' do
        it 'does not add policy stages to the pipeline_policy_context' do
          expect { run_chain }.not_to change {
            command.pipeline_policy_context.pipeline_execution_context.override_policy_stages
          }.from([])
        end
      end

      context 'with "override_project_ci" policy' do
        let(:override_policy) { build(:pipeline_execution_policy, :override_project_ci, name: 'Override') }
        let(:execution_policy_config) { build(:pipeline_execution_policy_config, policy: override_policy) }

        it 'adds policy stages to the pipeline_policy_context' do
          expect { run_chain }.to change {
            command.pipeline_policy_context.pipeline_execution_context.override_policy_stages
          }
                                    .to(%w[.pipeline-policy-pre .pre test policy-test .post .pipeline-policy-post])
        end

        context 'when stages are incompatible with other policy' do
          before do
            command.pipeline_policy_context.pipeline_execution_context.collect_declared_stages!(
              %w[.pipeline-policy-pre .pre build .post .pipeline-policy-post])
          end

          it 'raises OverrideStagesConflictError' do
            run_chain

            expect(step.break?).to be true
            expect(pipeline.errors.full_messages)
              .to contain_exactly("Policy `#{override_policy[:name]}` could not be applied. " \
                "Its stages are incompatible with stages of another `override_project_ci` policy: " \
                ".pipeline-policy-pre, .pre, build, .post, .pipeline-policy-post.")
          end
        end
      end

      it 'does not tracks the event' do
        expect { run_chain }
          .not_to trigger_internal_events('enforce_pipeline_execution_policy_in_project')
      end
    end

    private

    def run_previous_chain(pipeline, command)
      [
        Gitlab::Ci::Pipeline::Chain::Config::Content.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Config::Process.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Seed.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Populate.new(pipeline, command)
      ].map(&:perform!)
    end

    def perform_chain(pipeline, command)
      described_class.new(pipeline, command).perform!
    end
  end
end
