# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolApprovalHelper, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  where(:enabled, :locked, :expected_availability) do
    true  | false | :default_on
    false | false | :default_off
    false | true  | :never_on
  end

  with_them do
    describe '.to_session_availability' do
      it { expect(described_class.to_session_availability(enabled, locked)).to eq(expected_availability) }
    end

    describe '.enabled_for_session_availability' do
      it { expect(described_class.enabled_for_session_availability(expected_availability)).to eq(enabled) }
    end

    describe '.locked_for_session_availability' do
      it { expect(described_class.locked_for_session_availability(expected_availability)).to eq(locked) }
    end
  end

  describe '.to_session_availability' do
    it 'normalizes (enabled: true, locked: true) to :never_on' do
      expect(described_class.to_session_availability(true, true)).to eq(:never_on)
    end
  end

  describe '.enabled_for_session_availability' do
    it 'raises KeyError for invalid values' do
      expect { described_class.enabled_for_session_availability("invalid") }
        .to raise_error(KeyError)
    end
  end

  describe '.locked_for_session_availability' do
    it 'raises KeyError for invalid values' do
      expect { described_class.locked_for_session_availability("invalid") }
        .to raise_error(KeyError)
    end
  end
end
