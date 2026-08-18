# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService, feature_category: :security_policy_management do
  let(:service) { described_class.new(project: project, current_user: user, params: { content: content }) }
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  let(:content) do
    {
      variables: content_variables,
      include: [
        { template: 'Jobs/Secret-Detection.gitlab-ci.yml' },
        { template: 'Jobs/Dependency-Scanning.gitlab-ci.yml' }
      ]
    }
  end

  let(:content_variables) do
    {
      'ENVIRONMENT' => { value: 'staging', description: 'Value for environment.' }
    }
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    it 'extracts scanners by the declared artifacts:reports' do
      expect(execute).to be_success
      expect(execute.payload).to eq(
        enforced_scans: %w[secret_detection dependency_scanning],
        prefill_variables: content[:variables].deep_stringify_keys
      )
    end

    it 'passes project ref and sha to Gitlab::Ci::Config' do
      default_branch = project.default_branch_or_main
      default_sha = project.repository.root_ref_sha

      expect(Gitlab::Ci::Config).to receive(:new).with(
        anything,
        hash_including(
          project: project,
          user: user,
          ref: default_branch,
          sha: default_sha
        )
      ).and_call_original

      execute
    end

    describe 'prefill variables' do
      context 'when variables have mixed formats' do
        let(:content_variables) do
          {
            'VAR1' => { value: 'value1', description: 'var 1' },
            'VAR2' => { description: 'var 2' },
            'VAR3' => { value: 'value3', options: %w[value2 value3], description: 'var 3' },
            'VAR4' => { value: 'value4' },
            'VAR5' => 'value5'
          }
        end

        it 'only extracts variables with description' do
          expect(execute.payload).to match a_hash_including(prefill_variables: {
            'VAR1' => { value: 'value1', description: 'var 1' },
            'VAR2' => { description: 'var 2' },
            'VAR3' => { value: 'value3', options: %w[value2 value3], description: 'var 3' }
          })
        end
      end

      context 'when variables are not prefill variables' do
        context 'when variables do not declare description' do
          let(:content_variables) do
            {
              'ENVIRONMENT' => { value: 'value' }
            }
          end

          it 'does not extract the variables' do
            expect(execute.payload).to match a_hash_including(prefill_variables: {})
          end
        end

        context 'when variables are not a hash' do
          let(:content_variables) do
            {
              'ENVIRONMENT' => 'value'
            }
          end

          it 'does not extract the variables' do
            expect(execute.payload).to match a_hash_including(prefill_variables: {})
          end
        end
      end
    end

    context 'when a job with artifacts is declared manually' do
      let(:content) do
        {
          stages: ['test'],
          secrets: {
            script: 'script',
            artifacts: {
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            }
          }
        }
      end

      it 'extracts scanners by the declared artifacts:reports' do
        expect(execute).to be_success
        expect(execute.payload).to match(a_hash_including(enforced_scans: %w[secret_detection]))
      end
    end

    context 'when multiple jobs declare the same artifacts' do
      let(:content) do
        {
          include: [
            { template: 'Jobs/Secret-Detection.gitlab-ci.yml' }
          ],
          secrets: {
            script: 'script',
            artifacts: {
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            }
          }
        }
      end

      it 'extracts scanners without duplicates' do
        expect(execute).to be_success
        expect(execute.payload).to match(a_hash_including(enforced_scans: %w[secret_detection]))
      end
    end

    context 'when a job declares unsupported report_type' do
      let(:content) do
        {
          secret_detection: {
            script: 'script',
            artifacts: {
              reports: {
                cyclonedx: 'cyclonedx.json'
              }
            }
          }
        }
      end

      it 'returns an empty array' do
        expect(execute).to be_success
        expect(execute.payload).to eq(enforced_scans: [], prefill_variables: {})
      end
    end

    context 'when content is invalid' do
      let(:content) do
        { invalid_job: {} }
      end

      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message)
          .to include(
            'Error occurred while parsing the CI configuration',
            'jobs config should contain at least one visible job'
          )
        expect(execute.payload).to eq(enforced_scans: [], prefill_variables: {})
      end
    end

    context 'when error occurs while parsing the config' do
      let(:content) do
        {
          include: [{ project: 'invalid', file: 'invalid.yml' }]
        }
      end

      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message).to include('Project `invalid` not found or access denied!')
        expect(execute.payload).to eq(enforced_scans: [], prefill_variables: {})
      end
    end
  end
end
