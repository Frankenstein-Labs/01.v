# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::ComplianceManagement::ComplianceFrameworkPolicySummaryType,
  feature_category: :compliance_management do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('ComplianceFrameworkPolicySummary') }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(%w[name type source])
  end

  describe '#type' do
    subject(:resolved_type) { resolve_field(:type, policy_hash) }

    context 'when the policy type is scan_result_policy (legacy name)' do
      let(:policy_hash) { { name: 'Legacy Policy', type: 'scan_result_policy' } }

      it 'normalizes to approval_policy' do
        expect(resolved_type).to eq('approval_policy')
      end
    end

    context 'when the policy type is approval_policy' do
      let(:policy_hash) { { name: 'Approval Policy', type: 'approval_policy' } }

      it 'returns approval_policy unchanged' do
        expect(resolved_type).to eq('approval_policy')
      end
    end

    context 'when the policy type is scan_execution_policy' do
      let(:policy_hash) { { name: 'SEP Policy', type: 'scan_execution_policy' } }

      it 'returns scan_execution_policy unchanged' do
        expect(resolved_type).to eq('scan_execution_policy')
      end
    end

    context 'when the policy type is nil' do
      let(:policy_hash) { { name: 'Unnamed Policy', type: nil } }

      it 'returns nil' do
        expect(resolved_type).to be_nil
      end
    end
  end
end
