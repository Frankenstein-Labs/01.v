# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PipelineAuditor, feature_category: :security_policy_management do
  let_it_be(:auditor) { described_class.new(pipeline: build(:ci_pipeline)) }

  describe '#event_name' do
    it 'raises a NoMethodError with custom message' do
      expect do
        auditor.send(:event_name)
      end.to raise_error(NoMethodError, "#{described_class} must implement the method event_name")
    end
  end

  describe '#event_message' do
    it 'raises a NoMethodError with custom message' do
      expect do
        auditor.send(:event_message)
      end.to raise_error(NoMethodError, "#{described_class} must implement the method event_message")
    end
  end
end
