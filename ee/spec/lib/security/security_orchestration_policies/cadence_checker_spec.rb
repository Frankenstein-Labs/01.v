# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CadenceChecker, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  describe '#valid_cadence?' do
    let_it_be(:cadence_checker) { Class.new { include Security::SecurityOrchestrationPolicies::CadenceChecker }.new }

    where(:cadence, :expected_result) do
      '* * * * *' | false
      '*/30 * * * *' | false
      '0/5 18 * * *' | false
      '1,2,3,4,5,6 * * * *' | false
      '1-6 * * * *' | false
      '* 1-6 * * *' | false
      '* 0/6 * * *' | false
      '* */6 * * *' | false
      '* 1,2,3,4,5,6 * * *' | false
      '0 * * * *' | true
      '45 * * * *' | true
      '0 3 * * *' | true
      '0 3 * * 0' | true
      '0 16 * * *' | true
      '15 9 * * *' | true
      '00 16 * * *' | true
      '0 23 * * *' | true
      '30 13 * * *' | true
      '0 12 * * 6' | true
      '5 4 * * 1' | true
      '15 22 * * 6' | true
      '0 0 12 * *' | true
      '0 18 * * 3' | true
      '15 16 * * 2' | true
      '32 19 * * *' | true
      '0 12 * * 3' | true
      '0 15 * * Thu' | true
      '57 11 * * *' | true
      '40 8 * * *' | true
      '0 13 * * 3' | true
      '0 2 12,26 * *' | true
      '0 2 12-26 * *' | true
      '15 10 ? * MON-FRI' | true
      '15 10 ? * MON,FRI' | true
      '1 10 ? * 1-5' | true
      '1 10 * JAN *' | true
      '1 10 * JAN,FEB *' | true
      '1 10 * JAN-FEB *' | true
      '0 12 1/5 * ?' | true
    end

    with_them do
      it 'verifies if the cadence is allowed' do
        expect(cadence_checker.valid_cadence?(cadence)).to eq expected_result
      end
    end
  end
end
