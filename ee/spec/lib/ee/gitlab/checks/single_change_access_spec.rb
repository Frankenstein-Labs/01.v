# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Checks::SingleChangeAccess, feature_category: :source_code_management do
  include_context 'change access checks context'

  describe '#security_policy_bypass' do
    it 'returns a CombinedBypassChecker' do
      expect(change_access.security_policy_bypass)
        .to be_a(Security::ScanResultPolicies::CombinedBypassChecker)
    end

    it 'memoizes the result' do
      first_call = change_access.security_policy_bypass
      second_call = change_access.security_policy_bypass

      expect(first_call).to be(second_call)
    end
  end
end
