# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Processable, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  describe '#retryable?' do
    subject(:retryable) { build.retryable? }

    let(:pipeline) { merge_request.all_pipelines.order(:id).last }
    let(:build) { create(:ci_build, :failed, pipeline: pipeline) }

    context 'when the merge train pipeline is complete' do
      let(:merge_request) { create(:merge_request, :with_failed_merge_train_pipeline) }

      it { is_expected.to be(false) }
    end

    context 'when the merge train pipeline is running' do
      let(:merge_request) { create(:merge_request, :with_pending_merge_train_pipeline) }

      it { is_expected.to be(true) }
    end
  end

  describe '#dependency_variables' do
    let_it_be(:prepare_job) { create(:ci_build, pipeline: pipeline, stage_idx: 0, name: 'prepare') }
    let(:policy_job) do
      create(:ci_build, pipeline: pipeline, stage_idx: 1, name: 'policy_job', options: policy_job_options)
    end

    let(:policy_job_options) { { dependencies: [prepare_job.name] }.merge(policy_options) }

    let!(:job_artifact) { create(:ci_job_artifact, :dotenv, job: prepare_job) }
    let!(:dotenv_variable) do
      create(:ci_job_variable, :dotenv_source, job: prepare_job, key: 'PROTECTED_VAR', value: 'dotenv_value')
    end

    subject(:dependency_variables_result) { policy_job.dependency_variables.to_runner_variables }

    shared_examples 'allows dotenv variables' do
      it 'returns dotenv variables without filtering' do
        expect(dependency_variables_result).to contain_exactly(
          { key: 'PROTECTED_VAR', value: 'dotenv_value', public: false, masked: false }
        )
      end
    end

    shared_examples 'filters out dotenv variables' do
      it 'filters out dotenv variables' do
        expect(dependency_variables_result).to be_empty
      end
    end

    context 'when job is not a policy job' do
      let(:policy_options) { {} }

      it_behaves_like 'allows dotenv variables'
    end

    context 'when job is a policy job with variables_override' do
      context 'when variables_override.allowed is false (without dotenv option)' do
        let(:policy_options) do
          {
            policy: {
              pipeline_execution_policy_job: true,
              variables_override: {
                allowed: false,
                exceptions: []
              }
            }
          }
        end

        it_behaves_like 'filters out dotenv variables'

        context 'when dotenv: respect_policy is set' do
          let(:policy_options) do
            {
              policy: {
                pipeline_execution_policy_job: true,
                variables_override: {
                  allowed: false,
                  exceptions: [],
                  dotenv: 'respect_policy'
                }
              }
            }
          end

          it_behaves_like 'filters out dotenv variables'

          context 'when variable is in exceptions list' do
            let(:policy_options) do
              {
                policy: {
                  pipeline_execution_policy_job: true,
                  variables_override: {
                    allowed: false,
                    exceptions: ['PROTECTED_VAR'],
                    dotenv: 'respect_policy'
                  }
                }
              }
            end

            it_behaves_like 'allows dotenv variables'

            context 'when job has no dependencies' do
              let(:policy_job_options) { { dependencies: [] }.merge(policy_options) }

              it_behaves_like 'filters out dotenv variables'
            end
          end
        end
      end

      context 'when variables_override.allowed is true' do
        let(:policy_options) do
          {
            policy: {
              pipeline_execution_policy_job: true,
              variables_override: {
                allowed: true,
                exceptions: []
              }
            }
          }
        end

        it_behaves_like 'allows dotenv variables'

        context 'when variable is in exceptions list (denylist) without dotenv option' do
          let(:policy_options) do
            {
              policy: {
                pipeline_execution_policy_job: true,
                variables_override: {
                  allowed: true,
                  exceptions: ['PROTECTED_VAR']
                }
              }
            }
          end

          it_behaves_like 'filters out dotenv variables'
        end

        context 'when dotenv: respect_policy is set with denylist' do
          let(:policy_options) do
            {
              policy: {
                pipeline_execution_policy_job: true,
                variables_override: {
                  allowed: true,
                  exceptions: ['PROTECTED_VAR'],
                  dotenv: 'respect_policy'
                }
              }
            }
          end

          it_behaves_like 'filters out dotenv variables'
        end

        context 'when dotenv: allow_override is explicitly set' do
          let(:policy_options) do
            {
              policy: {
                pipeline_execution_policy_job: true,
                variables_override: {
                  allowed: true,
                  exceptions: ['PROTECTED_VAR'],
                  dotenv: 'allow_override'
                }
              }
            }
          end

          it_behaves_like 'allows dotenv variables'
        end
      end
    end

    context 'when job uses legacy execution_policy_job format' do
      let(:policy_options) do
        {
          execution_policy_job: true,
          execution_policy_variables_override: {
            allowed: false,
            exceptions: []
          }
        }
      end

      it_behaves_like 'filters out dotenv variables'

      context 'when dotenv: respect_policy is set' do
        let(:policy_options) do
          {
            execution_policy_job: true,
            execution_policy_variables_override: {
              allowed: false,
              exceptions: [],
              dotenv: 'respect_policy'
            }
          }
        end

        it_behaves_like 'filters out dotenv variables'
      end
    end

    context 'with multiple dotenv variables and dotenv: respect_policy' do
      let!(:dotenv_variable2) do
        create(:ci_job_variable, :dotenv_source, job: prepare_job, key: 'ANOTHER_VAR', value: 'another_value')
      end

      let(:policy_options) do
        {
          policy: {
            pipeline_execution_policy_job: true,
            variables_override: {
              allowed: false,
              exceptions: ['PROTECTED_VAR'],
              dotenv: 'respect_policy'
            }
          }
        }
      end

      it_behaves_like 'allows dotenv variables'
    end
  end
end
