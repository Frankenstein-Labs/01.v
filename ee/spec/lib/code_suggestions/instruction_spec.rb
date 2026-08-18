# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Instruction, feature_category: :code_suggestions do
  describe '#instruction' do
    subject(:instruction) { described_class.from_trigger_type(type).instruction }

    using RSpec::Parameterized::TableSyntax

    where(:type, :expected_instruction) do
      'empty_function' | described_class::EMPTY_FUNCTION_INSTRUCTION
      'small_file'     | described_class::SMALL_FILE_INSTRUCTION
      'comment'        | ''
    end

    with_them do
      it 'sets instruction based on trigger type' do
        expect(instruction).to eq(expected_instruction)
      end
    end

    context 'when trigger type is unknown' do
      let(:type) { :unknown }

      it 'raises an error' do
        expect { instruction }.to raise_exception(ArgumentError)
      end
    end
  end
end
