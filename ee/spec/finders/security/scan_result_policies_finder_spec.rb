# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPoliciesFinder, feature_category: :security_policy_management do
  let!(:approval_policy) do
    build(:approval_policy, name: 'Contains security critical', policy_scope: policy_scope)
  end

  let!(:policy_yaml) do
    build(:orchestration_policy_yaml, approval_policy: [approval_policy])
  end

  let(:policy) { approval_policy.merge({ type: 'approval_policy' }) }
  let(:expected_extra_attrs) { { policy_index: 0 } }

  include_context 'with security policies information'

  it_behaves_like 'security policies finder'
end
