# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::Error, feature_category: :source_code_management do
  let(:line_number) { 1 }
  let(:message) { :invalid_approval_requirement }

  subject(:error) { described_class.new(message, line_number) }

  describe '::new(message, line_number)' do
    it 'exposes message and line_number', :aggregate_failures do
      expect(error.message).to eq(message)
      expect(error.line_number).to eq(line_number)
    end
  end

  describe '#==(other)' do
    subject { error == other }

    context 'when comparing the same error' do
      let(:other) { error }

      it { is_expected.to be_truthy }
    end

    context 'when comparing another error' do
      using RSpec::Parameterized::TableSyntax

      let(:other) { described_class.new(other_message, other_line_number) }

      where(:other_message, :other_line_number, :expected_equality) do
        ref(:message)               | ref(:line_number) | true
        :invalid_entry_owner_format | ref(:line_number) | false
        ref(:message)               | 2                 | false
        :invalid_entry_owner_format | 2                 | false
      end

      with_them do
        it { is_expected.to eq(expected_equality) }
      end
    end
  end
end
