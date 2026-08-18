# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::VariablesOverride, feature_category: :security_policy_management do
  describe '#allowed' do
    context 'when allowed is true' do
      it 'returns true' do
        variables_override = described_class.new({ allowed: true })
        expect(variables_override.allowed).to be true
      end
    end

    context 'when allowed is false' do
      it 'returns false' do
        variables_override = described_class.new({ allowed: false })
        expect(variables_override.allowed).to be false
      end
    end

    context 'when allowed is not present' do
      it 'returns nil' do
        variables_override = described_class.new({})
        expect(variables_override.allowed).to be_nil
      end
    end
  end

  describe '#exceptions' do
    context 'when exceptions is present' do
      it 'returns the exceptions array' do
        exceptions = %w[VAR1 VAR2 VAR3]
        variables_override = described_class.new({ allowed: false, exceptions: exceptions })
        expect(variables_override.exceptions).to match_array(exceptions)
      end

      it 'handles single exception' do
        exceptions = ['VAR1']
        variables_override = described_class.new({ allowed: false, exceptions: exceptions })
        expect(variables_override.exceptions).to match_array(exceptions)
      end

      it 'handles empty exceptions array' do
        exceptions = []
        variables_override = described_class.new({ allowed: false, exceptions: exceptions })
        expect(variables_override.exceptions).to be_empty
      end
    end

    context 'when exceptions is not present' do
      it 'returns an empty array' do
        variables_override = described_class.new({ allowed: true })
        expect(variables_override.exceptions).to be_empty
      end
    end

    context 'when variables_override is nil' do
      it 'returns an empty array' do
        variables_override = described_class.new(nil)
        expect(variables_override.exceptions).to be_empty
      end
    end
  end

  describe 'complete variables_override configuration' do
    it 'handles variables_override with allowed false and exceptions' do
      variables_override_data = {
        allowed: false,
        exceptions: %w[VAR1 VAR2 VAR3]
      }
      variables_override = described_class.new(variables_override_data)

      expect(variables_override.allowed).to be false
      expect(variables_override.exceptions.length).to eq(3)
      expect(variables_override.exceptions).to match_array(%w[VAR1 VAR2 VAR3])
    end

    it 'handles variables_override with allowed true and no exceptions' do
      variables_override_data = {
        allowed: true
      }
      variables_override = described_class.new(variables_override_data)

      expect(variables_override.allowed).to be true
      expect(variables_override.exceptions).to be_empty
    end

    it 'handles variables_override with allowed false and empty exceptions' do
      variables_override_data = {
        allowed: false,
        exceptions: []
      }
      variables_override = described_class.new(variables_override_data)

      expect(variables_override.allowed).to be false
      expect(variables_override.exceptions).to be_empty
    end
  end
end
