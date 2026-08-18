# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiAction::Base,
  feature_category: :security_policy_management do
  describe '#config' do
    it 'raises an error' do
      expect { described_class.new(anything, anything, anything, 0).config }.to raise_error(NotImplementedError)
    end
  end

  describe '#generate_job_name_with_index' do
    def job_name(suffix)
      described_class
        .new(anything, anything, anything, 1, { job_name_suffix: suffix })
        .send(:generate_job_name_with_index, 'secret_detection')
    end

    it 'appends the suffix as its own dash-delimited segment', :aggregate_failures do
      expect(job_name(nil)).to eq(:'secret-detection-1')
      expect(job_name('')).to eq(:'secret-detection-1')
      expect(job_name('profile')).to eq(:'secret-detection-profile-1')
    end
  end
end
