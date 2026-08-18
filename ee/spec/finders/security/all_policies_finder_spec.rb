# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AllPoliciesFinder, feature_category: :security_policy_management do
  include_context 'with security policies information'

  %i[pipeline_execution_schedule_policy scan_execution_policy pipeline_execution_policy approval_policy
    vulnerability_management_policy].each do |policy_type|
    context "with policy type #{policy_type}" do
      let(:policy) do
        build(policy_type, name: 'My policy', policy_scope: policy_scope)
      end

      let(:policy_yaml) do
        build(:orchestration_policy_yaml, policy_type => [policy])
      end

      it_behaves_like 'security policies finder' do
        let(:expected_extra_attrs) { { type: policy_type.to_s, policy_index: 0 } }
      end
    end
  end

  context 'with all_policies and with type' do
    let(:scan_execution_policy) { build(:scan_execution_policy, name: 'Scan Policy') }
    let(:approval_policy) { build(:approval_policy, name: 'Approval Policy') }
    let(:pipeline_execution_policy) { build(:pipeline_execution_policy, name: 'Pipeline Policy') }
    let(:pipeline_execution_schedule_policy) { build(:pipeline_execution_schedule_policy, name: 'Schedule Policy') }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml,
        scan_execution_policy: [scan_execution_policy],
        approval_policy: [approval_policy],
        pipeline_execution_policy: [pipeline_execution_policy],
        pipeline_execution_schedule_policy: [pipeline_execution_schedule_policy]
      )
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
      object.add_developer(actor)
    end

    {
      scan_execution_policy: 'scan_execution_policy',
      approval_policy: 'approval_policy',
      pipeline_execution_policy: 'pipeline_execution_policy',
      pipeline_execution_schedule_policy: 'pipeline_execution_schedule_policy'
    }.each do |type_sym, type_str|
      context "when filtering by type '#{type_str}'" do
        let(:params) { { type: type_str } }

        it 'returns only the policy of the requested type' do
          result = described_class.new(actor, object, params).execute
          expect(result).to all(include(type: type_str))
          expect(result.size).to eq(1)
          expect(result.first[:name]).to eq(
            case type_sym
            when :scan_execution_policy then scan_execution_policy[:name]
            when :approval_policy then approval_policy[:name]
            when :pipeline_execution_policy then pipeline_execution_policy[:name]
            when :pipeline_execution_schedule_policy then pipeline_execution_schedule_policy[:name]
            end
          )
        end
      end
    end
  end
end
