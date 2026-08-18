# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::ProtectedBranches::BasePolicyCheck, feature_category: :security_policy_management do
  describe '#violated?' do
    it 'raises for the abstract base class' do
      expect { described_class.new(nil, nil).violated? }.to raise_error(NotImplementedError)
    end
  end

  describe 'PolicyViolationError' do
    it 'is a subclass of AccessDeniedError so existing rescue handlers keep working' do
      expect(described_class::PolicyViolationError.ancestors).to include(::Gitlab::Access::AccessDeniedError)
    end
  end

  describe '.check!' do
    let(:check_class) do
      Class.new(described_class) do
        def initialize(violated:)
          @violated = violated
          super(nil, nil)
        end

        def violated?
          @violated
        end

        private

        def violation_message
          'blocked by a test policy'
        end
      end
    end

    context 'when the check is violated' do
      it 'raises PolicyViolationError with the violation message' do
        expect { check_class.new(violated: true).check! }
          .to raise_error(described_class::PolicyViolationError, 'blocked by a test policy')
      end
    end

    context 'when the check is not violated' do
      it 'does not raise' do
        expect { check_class.new(violated: false).check! }.not_to raise_error
      end
    end
  end
end
