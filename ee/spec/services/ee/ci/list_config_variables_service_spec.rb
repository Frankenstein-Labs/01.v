# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ListConfigVariablesService,
  :use_clean_rails_memory_store_caching, feature_category: :pipeline_composition do
  include ReactiveCachingHelpers

  let_it_be(:ci_config) do
    {
      variables: {
        KEY1: { value: 'val 1', description: 'description 1' },
        KEY2: { value: 'val 2', description: '' },
        KEY3: { value: 'val 3' },
        KEY4: 'val 4'
      },
      test: {
        stage: 'test',
        script: 'echo'
      }
    }
  end

  let_it_be(:files) { { '.gitlab-ci.yml' => YAML.dump(ci_config) } }
  let_it_be(:project) { create(:project, :custom_repo, :auto_devops_disabled, files: files) }
  let(:user) { project.creator }
  let(:ref) { project.default_branch }
  let(:service) { described_class.new(project, user) }

  subject(:result) { service.execute(ref) }

  before do
    synchronous_reactive_cache(service)
  end

  describe 'variables from pipeline execution policies' do
    let(:expected_result) do
      {
        'KEY1' => { value: 'val 1', description: 'description 1' },
        'KEY2' => { value: 'val 2', description: '' },
        'KEY3' => { value: 'val 3' },
        'KEY4' => { value: 'val 4' },
        'PEP_KEY1' => { value: 'pep val 1', description: 'pep description 1' },
        'PEP_KEY2' => { value: 'pep val 2', description: 'pep description 2' }
      }
    end

    let(:policy1_variables) do
      {
        'PEP_KEY1' => { value: 'pep val 1', description: 'pep description 1' }
      }
    end

    let(:policy2_variables) do
      {
        'PEP_KEY2' => { value: 'pep val 2', description: 'pep description 2' }
      }
    end

    before do
      create(:security_policy, :pipeline_execution_policy,
        linked_projects: [project],
        metadata: { prefill_variables: policy1_variables })
      create(:security_policy, :pipeline_execution_policy,
        linked_projects: [project],
        metadata: { prefill_variables: policy2_variables })
    end

    it 'returns a combined variables list' do
      expect(result).to eq(expected_result)
    end
  end

  describe 'when project has no .gitlab-ci.yml' do
    let_it_be(:project_without_ci) { create(:project, :auto_devops_disabled) }
    let(:user) { project_without_ci.creator }
    let(:ref) { project_without_ci.default_branch }
    let(:service) { described_class.new(project_without_ci, user) }

    let(:policy_variables) do
      {
        'PEP_KEY1' => { value: 'pep val 1', description: 'pep description 1' }
      }
    end

    context 'when pipeline execution policies with prefill variables exist' do
      before do
        create(:security_policy, :pipeline_execution_policy,
          linked_projects: [project_without_ci],
          metadata: { prefill_variables: policy_variables })
      end

      it 'returns policy variables even without a .gitlab-ci.yml' do
        expect(result).to eq({
          'PEP_KEY1' => { value: 'pep val 1', description: 'pep description 1' }
        })
      end
    end

    context 'when no pipeline execution policies exist' do
      it 'returns an empty hash' do
        expect(result).to eq({})
      end
    end
  end
end
