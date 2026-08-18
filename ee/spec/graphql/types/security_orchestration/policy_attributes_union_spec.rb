# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::SecurityOrchestration::PolicyAttributesUnion, feature_category: :security_policy_management do
  describe '.possible_types' do
    it 'includes all expected types' do
      expected_types = [
        Types::SecurityOrchestration::ApprovalPolicyAttributesType,
        Types::SecurityOrchestration::ScanExecutionPolicyAttributesType,
        Types::SecurityOrchestration::PipelineExecutionPolicyAttributesType,
        Types::Security::VulnerabilityManagementPolicyAttributesType,
        Types::SecurityOrchestration::PipelineExecutionScheduledPolicyAttributesType,
        Types::Security::DependencyFirewallPolicyAttributesType
      ]
      expect(described_class.possible_types).to match_array(expected_types)
    end
  end

  describe '.resolve_type' do
    it 'returns the correct type for approval_policy' do
      object = { type: 'approval_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::SecurityOrchestration::ApprovalPolicyAttributesType)
    end

    it 'returns the correct type for scan_execution_policy' do
      object = { type: 'scan_execution_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::SecurityOrchestration::ScanExecutionPolicyAttributesType)
    end

    it 'returns the correct type for pipeline_execution_policy' do
      object = { type: 'pipeline_execution_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::SecurityOrchestration::PipelineExecutionPolicyAttributesType)
    end

    it 'returns the correct type for pipeline_execution_schedule_policy' do
      object = { type: 'pipeline_execution_schedule_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::SecurityOrchestration::PipelineExecutionScheduledPolicyAttributesType)
    end

    it 'returns the correct type for vulnerability_management_policy' do
      object = { type: 'vulnerability_management_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::Security::VulnerabilityManagementPolicyAttributesType)
    end

    it 'returns the correct type for dependency_firewall_policy' do
      object = { type: 'dependency_firewall_policy' }
      expect(described_class.resolve_type(object,
        nil)).to eq(Types::Security::DependencyFirewallPolicyAttributesType)
    end

    it 'returns nil for unknown type' do
      object = { type: 'unknown_policy' }
      expect(described_class.resolve_type(object, nil)).to be_nil
    end
  end
end
