# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :small_repo) }

  let(:ref) { "refs/heads/#{project.default_branch}" }
  let(:pipeline_source) { :push }

  subject(:context) { described_class.new(project: project, ref: ref, pipeline_source: pipeline_source) }

  describe '#eligible?' do
    it 'delegates to the eligibility service' do
      allow(context.send(:eligibility_service)).to receive(:eligible?).and_return(true)

      expect(context.eligible?).to be true
    end
  end

  describe '#applicable_profiles_triggers' do
    it 'delegates to the eligibility service' do
      triggers = double
      allow(context.send(:eligibility_service)).to receive(:applicable_profiles_triggers).and_return(triggers)

      expect(context.applicable_profiles_triggers).to eq(triggers)
    end
  end

  describe '#collect_injected_job_names_with_metadata and #job_injected?' do
    let(:metadata_key) { ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY }

    let(:template) do
      {
        'sast-0': { stage: 'test', script: ['run'], metadata_key => { profile_id: 10 } },
        'secret-detection-0': { stage: 'test', script: ['run'], metadata_key => { profile_id: 20 } },
        variables: { 'VAR' => 'value' }
      }
    end

    it 'tracks injected job names from template metadata' do
      context.collect_injected_job_names_with_metadata(template)

      expect(context.job_injected?('sast-0')).to be true
      expect(context.job_injected?(:'secret-detection-0')).to be true
      expect(context.job_injected?('rspec')).to be false
    end

    it 'excludes non-job keys like variables' do
      context.collect_injected_job_names_with_metadata(template)

      expect(context.job_injected?(:variables)).to be false
    end

    it 'accumulates job names across multiple calls' do
      context.collect_injected_job_names_with_metadata(
        { sast: { script: ['run'], metadata_key => { profile_id: 10 } } }
      )
      context.collect_injected_job_names_with_metadata(
        { 'secret-detection-0': { script: ['run'], metadata_key => { profile_id: 20 } } }
      )

      expect(context.job_injected?(:sast)).to be true
      expect(context.job_injected?(:'secret-detection-0')).to be true
    end

    it 'returns false when no job names have been collected' do
      expect(context.job_injected?('sast-0')).to be false
    end

    context 'when template contains non-Hash job values' do
      let(:template) do
        {
          'sast-0': { stage: 'test', script: ['run'], metadata_key => { profile_id: 10 } },
          'non-hash-job': 'some_string_value'
        }
      end

      it 'extracts nil metadata for non-Hash values' do
        context.collect_injected_job_names_with_metadata(template)

        expect(context.job_injected?(:'sast-0')).to be true
        expect(context.job_injected?(:'non-hash-job')).to be true
        expect(context.profile_id_for_job(:'non-hash-job')).to be_nil
      end
    end
  end

  describe '#each_injected_job_with_profile_id' do
    let(:metadata_key) { ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY }

    before do
      context.collect_injected_job_names_with_metadata(
        {
          'sast-0': { script: ['run'], metadata_key => { profile_id: 10 } },
          'secret-detection-0': { script: ['run'], metadata_key => { profile_id: 20 } },
          'no-profile': { script: ['run'], metadata_key => {} }
        }
      )
    end

    it 'yields only jobs with a profile_id' do
      yielded = []
      context.each_injected_job_with_profile_id { |name, id| yielded << [name, id] }

      expect(yielded).to match_array([['sast-0', 10], ['secret-detection-0', 20]])
    end

    it 'skips jobs with nil metadata' do
      context.collect_injected_job_names_with_metadata(
        { 'nil-meta': { script: ['run'] } }
      )

      yielded = []
      context.each_injected_job_with_profile_id { |name, id| yielded << [name, id] }

      expect(yielded).to match_array([['sast-0', 10], ['secret-detection-0', 20]])
    end
  end

  describe '#profile_id_for_job' do
    let(:metadata_key) { ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY }

    it 'returns the profile ID from job metadata' do
      context.collect_injected_job_names_with_metadata(
        {
          'sast-0': { script: ['run'], metadata_key => { profile_id: 10 } },
          'secret-detection-0': { script: ['run'], metadata_key => { profile_id: 20 } }
        }
      )

      expect(context.profile_id_for_job('sast-0')).to eq(10)
      expect(context.profile_id_for_job(:'secret-detection-0')).to eq(20)
    end

    it 'returns nil for an unknown job' do
      context.collect_injected_job_names_with_metadata(
        { 'sast-0': { script: ['run'], metadata_key => { profile_id: 10 } } }
      )

      expect(context.profile_id_for_job('rspec')).to be_nil
    end

    it 'returns nil when metadata has no profile_id' do
      context.collect_injected_job_names_with_metadata(
        { 'sast-0': { script: ['run'], metadata_key => {} } }
      )

      expect(context.profile_id_for_job('sast-0')).to be_nil
    end
  end
end
