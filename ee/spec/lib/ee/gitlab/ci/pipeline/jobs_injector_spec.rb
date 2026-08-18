# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::JobsInjector, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:pipeline) do
    build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
      pipeline.stages = [build(:ci_stage, name: 'test', position: 1, pipeline: pipeline).tap do |stage|
        stage.statuses = [build(:ci_build, name: 'test-job', stage_idx: 1)]
      end]
    end
  end

  let(:pipeline_stage) { pipeline.stages.first }
  let(:stage_to_inject) { build(:ci_stage, name: 'build', position: 3, pipeline: build(:ci_empty_pipeline)) }
  let(:job_to_inject) do
    build(:ci_build, name: 'build-job', stage_idx: 3, stage: stage_to_inject)
  end

  let(:declared_stages) { %w[build test deploy] }
  let(:jobs_to_inject) { [job_to_inject] }
  let(:on_conflict) { nil }
  let(:service) { described_class.new(pipeline: pipeline, declared_stages: declared_stages, on_conflict: on_conflict) }
  let(:injected_job) { pipeline_stage.statuses.find { |status| status.name == job_to_inject.name } }

  describe '#inject_jobs' do
    subject(:inject) { service.inject_jobs(jobs: jobs_to_inject, stage: stage_to_inject) }

    describe 'stage injection' do
      let(:injected_stage) { pipeline.stages.find { |stage| stage.name == stage_to_inject.name } }

      it 'adds the stage to the target pipeline' do
        expect { inject }.to change { pipeline.stages.size }.by(1)

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
      end

      it 'assigns correct stage attributes based on the target pipeline' do
        inject

        expect(injected_stage).to have_attributes(pipeline: pipeline, position: 0)
      end

      context 'when stage already exists in the pipeline' do
        let(:other_pipeline) { build(:ci_empty_pipeline) }
        let(:stage_to_inject) { build(:ci_stage, name: 'test', position: 2, pipeline: other_pipeline) }

        it 'does not change the existing pipeline stages' do
          expect { inject }.not_to change { pipeline.stages.size }.from(1)

          existing_stage = pipeline.stages.first
          expect(existing_stage).to have_attributes(pipeline: pipeline, position: 1)
        end
      end

      context 'when stage does not exist in declared_stages' do
        let(:declared_stages) { %w[test] }

        it 'does not change the pipeline stages' do
          expect { inject }.not_to change { pipeline.stages.size }
        end

        context 'with multiple jobs' do
          let(:job_to_inject_2) do
            build(:ci_build, name: 'build-job-2', stage_idx: 3, stage: stage_to_inject)
          end

          let(:jobs_to_inject) { [job_to_inject, job_to_inject_2] }

          it 'does not change the pipeline stages' do
            expect { inject }.not_to change { pipeline.stages.size }
            expect(pipeline.stages.map(&:name)).to contain_exactly('test')
            expect(pipeline_stage.statuses.map(&:name)).to contain_exactly 'test-job'
          end
        end
      end
    end

    describe 'job injection' do
      let(:stage_to_inject) { build(:ci_stage, name: pipeline_stage.name, position: 3) }

      it 'adds the job to the target stage' do
        expect { inject }.to change { pipeline_stage.statuses.size }.by(1)

        expect(pipeline_stage.statuses.map(&:name)).to contain_exactly('build-job', 'test-job')
      end

      it 'assigns correct attributes based on the target stage' do
        inject

        expect(injected_job).to have_attributes(pipeline: pipeline, stage_idx: 1)
      end

      context 'with on_conflict' do
        let(:on_conflict) { ->(job_name) { "#{job_name}:suffix" } }

        context 'without conflicts' do
          it 'injects the job with the same name' do
            inject

            expect(injected_job.name).to eq 'build-job'
          end

          context 'when job has needs' do
            before do
              job_to_inject.needs << build(:ci_build_need, name: 'test-job')
            end

            it 'does not update the needs with the suffix' do
              inject

              expect(injected_job.needs.first.name).to eq 'test-job'
            end
          end
        end

        context 'with conflicts' do
          let(:job_to_inject) do
            build(:ci_build, name: 'test-job', stage_idx: 3)
          end

          it 'adds suffix to the injected job' do
            inject

            expect(injected_job.name).to eq 'test-job:suffix'
          end

          context 'when jobs have needs' do
            let(:jobs_to_inject) { [job_to_inject, job_with_needs_to_inject] }
            let(:job_with_needs_to_inject) do
              build(:ci_build, name: 'other-job', stage_idx: 4).tap do |job|
                job.needs << build(:ci_build_need, name: 'test-job')
              end
            end

            it 'updates the needs with the suffix' do
              inject

              injected_job_with_needs = pipeline_stage.statuses
                                                      .find { |status| status.name == job_with_needs_to_inject.name }
              expect(injected_job_with_needs.needs.first.name).to eq 'test-job:suffix'
            end
          end

          context 'when job has unrelated needs that were not renamed' do
            it 'does not add the suffix' do
              job_to_inject.needs << build(:ci_build_need, name: 'other-job')
              inject

              expect(injected_job.needs.first.name).to eq 'other-job'
            end
          end

          context 'when on_conflict lambda returns nil' do
            let(:on_conflict) { ->(_job_name) { nil } }

            it 'injects the job with the same name' do
              expect { inject }.to raise_error(
                ::Gitlab::Ci::Pipeline::JobsInjector::DuplicateJobNameError, 'job names must be unique (test-job)'
              )
            end
          end

          context 'when the conflicting job is a parallelized variant' do
            let(:pipeline) do
              build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
                pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
                  stage.statuses = [
                    build(:ci_build, name: 'build 1/3', stage_idx: 0),
                    build(:ci_build, name: 'build 2/3', stage_idx: 0),
                    build(:ci_build, name: 'build 3/3', stage_idx: 0)
                  ]
                end]
              end
            end

            let(:stage_to_inject) { build(:ci_stage, name: 'build', position: 0, pipeline: build(:ci_empty_pipeline)) }
            let(:declared_stages) { %w[build] }

            let(:jobs_to_inject) do
              [
                build(:ci_build, name: 'build 1/3', stage_idx: 0, stage: stage_to_inject),
                build(:ci_build, name: 'build 2/3', stage_idx: 0, stage: stage_to_inject),
                build(:ci_build, name: 'build 3/3', stage_idx: 0, stage: stage_to_inject)
              ]
            end

            it 'inserts the suffix before the parallel marker so variants share a group name',
              :aggregate_failures do
              inject

              build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
              renamed_names = build_stage.statuses
                .map(&:name)
                .grep(/:suffix/)
              expect(renamed_names).to contain_exactly('build:suffix 1/3', 'build:suffix 2/3', 'build:suffix 3/3')
              expect(renamed_names.map { |name| ::Gitlab::Utils::Job.group_name(name) }.uniq)
                .to contain_exactly('build:suffix')
            end
          end

          context 'when the conflicting job is a matrix variant' do
            let(:pipeline) do
              build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
                pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
                  stage.statuses = [
                    build(:ci_build, name: 'build: [aws]', stage_idx: 0),
                    build(:ci_build, name: 'build: [gcp]', stage_idx: 0)
                  ]
                end]
              end
            end

            let(:stage_to_inject) { build(:ci_stage, name: 'build', position: 0, pipeline: build(:ci_empty_pipeline)) }
            let(:declared_stages) { %w[build] }

            let(:jobs_to_inject) do
              [
                build(:ci_build, name: 'build: [aws]', stage_idx: 0, stage: stage_to_inject),
                build(:ci_build, name: 'build: [gcp]', stage_idx: 0, stage: stage_to_inject)
              ]
            end

            it 'inserts the suffix before the matrix marker so variants share a group name',
              :aggregate_failures do
              inject

              build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
              renamed_names = build_stage.statuses
                .map(&:name)
                .grep(/:suffix/)
              expect(renamed_names).to contain_exactly('build:suffix: [aws]', 'build:suffix: [gcp]')
              expect(renamed_names.map { |name| ::Gitlab::Utils::Job.group_name(name) }.uniq)
                .to contain_exactly('build:suffix')
            end
          end
        end
      end
    end

    describe 'expanding needs for parallelized jobs' do
      let(:job_name_mappings) { { build: ['build: [linux]', 'build: [macos]'] } }
      let(:service) do
        described_class.new(
          pipeline: pipeline,
          declared_stages: declared_stages,
          on_conflict: on_conflict,
          job_name_mappings: job_name_mappings
        )
      end

      let(:pipeline) do
        build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
          pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
            stage.statuses = [
              build(:ci_build, name: 'build: [linux]', stage_idx: 0),
              build(:ci_build, name: 'build: [macos]', stage_idx: 0)
            ]
          end]
        end
      end

      let(:stage_to_inject) { build(:ci_stage, name: 'test', position: 1, pipeline: build(:ci_empty_pipeline)) }
      let(:declared_stages) { %w[build test] }

      context 'when policy job has needs on a parallelized matrix job' do
        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'build', optional: true, artifacts: true)
          end
        end

        it 'expands the needs to all parallelized job variants' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('build: [linux]', 'build: [macos]')
        end

        it 'preserves need attributes like optional and artifacts' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          injected.needs.each do |need|
            expect(need.optional).to be(true)
            expect(need.artifacts).to be(true)
          end
        end
      end

      context 'when policy job has needs on a number parallel job' do
        let(:job_name_mappings) { { test: ['test 1/3', 'test 2/3', 'test 3/3'] } }

        let(:pipeline) do
          build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
            pipeline.stages = [build(:ci_stage, name: 'test', position: 0, pipeline: pipeline).tap do |stage|
              stage.statuses = [
                build(:ci_build, name: 'test 1/3', stage_idx: 0),
                build(:ci_build, name: 'test 2/3', stage_idx: 0),
                build(:ci_build, name: 'test 3/3', stage_idx: 0)
              ]
            end]
          end
        end

        let(:stage_to_inject) { build(:ci_stage, name: 'deploy', position: 1, pipeline: build(:ci_empty_pipeline)) }
        let(:declared_stages) { %w[test deploy] }

        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'test', optional: true)
          end
        end

        it 'expands the needs to all parallelized job variants' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('test 1/3', 'test 2/3', 'test 3/3')
        end
      end

      context 'when policy job has needs on a non-parallelized job' do
        let(:job_name_mappings) { {} }

        let(:pipeline) do
          build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
            pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
              stage.statuses = [build(:ci_build, name: 'build', stage_idx: 0)]
            end]
          end
        end

        let(:stage_to_inject) { build(:ci_stage, name: 'test', position: 1, pipeline: build(:ci_empty_pipeline)) }
        let(:declared_stages) { %w[build test] }

        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'build', optional: true)
          end
        end

        it 'keeps the original needs unchanged' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('build')
        end
      end

      context 'when policy job has needs on a job that does not exist and has no mapping' do
        let(:job_name_mappings) { {} }

        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'nonexistent', optional: true)
          end
        end

        it 'keeps the original needs unchanged (for optional needs)' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('nonexistent')
        end
      end

      context 'when an injected job is renamed and its name matches a parallelized variant' do
        let(:on_conflict) { ->(job_name) { "#{job_name}:suffix" } }
        let(:job_name_mappings) { { build: ['build 1/2', 'build 2/2'] } }

        let(:pipeline) do
          build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
            pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
              stage.statuses = [
                build(:ci_build, name: 'build 1/2', stage_idx: 0),
                build(:ci_build, name: 'build 2/2', stage_idx: 0)
              ]
            end]
          end
        end

        let(:conflicting_job) do
          build(:ci_build, name: 'build 1/2', stage_idx: 1, stage: stage_to_inject)
        end

        let(:needing_job) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'build', optional: true)
          end
        end

        let(:jobs_to_inject) { [conflicting_job, needing_job] }

        it 'expands needs to the original parallelized variants, not the renamed conflict' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('build 1/2', 'build 2/2')
        end
      end

      context 'when policy job has mixed needs (parallelized and non-parallelized)' do
        let(:job_name_mappings) { { build: ['build: [linux]', 'build: [macos]'] } }

        let(:pipeline) do
          build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
            pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
              stage.statuses = [
                build(:ci_build, name: 'build: [linux]', stage_idx: 0),
                build(:ci_build, name: 'build: [macos]', stage_idx: 0),
                build(:ci_build, name: 'lint', stage_idx: 0)
              ]
            end]
          end
        end

        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'build', optional: true)
            job.needs << build(:ci_build_need, name: 'lint', optional: true)
          end
        end

        it 'expands parallelized needs and keeps non-parallelized needs unchanged' do
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to contain_exactly('build: [linux]', 'build: [macos]', 'lint')
        end
      end

      context 'when a non-parallel policy job shadows parallelized variants of the project job' do
        let(:job_name_mappings) { { build: ['build: [aws]', 'build: [gcp]'] } }

        let(:pipeline) do
          build(:ci_pipeline, project: project, ref: 'master', user: user).tap do |pipeline|
            pipeline.stages = [build(:ci_stage, name: 'build', position: 0, pipeline: pipeline).tap do |stage|
              stage.statuses = [
                build(:ci_build, name: 'build: [aws]', stage_idx: 0),
                build(:ci_build, name: 'build: [gcp]', stage_idx: 0)
              ]
            end]
          end
        end

        let(:declared_stages) { %w[build test] }

        let(:policy_a_stage) { build(:ci_stage, name: 'build', position: 0, pipeline: build(:ci_empty_pipeline)) }
        let(:policy_a_build_job) { build(:ci_build, name: 'build', stage_idx: 0, stage: policy_a_stage) }

        let(:stage_to_inject) { build(:ci_stage, name: 'test', position: 1, pipeline: build(:ci_empty_pipeline)) }
        let(:job_to_inject) do
          build(:ci_build, name: 'policy-job', stage_idx: 1, stage: stage_to_inject).tap do |job|
            job.needs << build(:ci_build_need, name: 'build', optional: true)
          end
        end

        it 'still expands needs to the parallelized variants' do
          service.inject_jobs(jobs: [policy_a_build_job], stage: policy_a_stage)
          inject

          injected = pipeline.stages.flat_map(&:statuses).find { |s| s.name == 'policy-job' }
          expect(injected.needs.map(&:name)).to include('build: [aws]', 'build: [gcp]')
        end
      end
    end
  end
end
