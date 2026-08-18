# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::FileContent, feature_category: :code_suggestions do
  describe '#small?' do
    subject { described_class.new(language, content_above_cursor, content_below_cursor) }

    let(:language) do
      CodeSuggestions::ProgrammingLanguage.new('Ruby')
    end

    context 'when file content around cursor is less than 5 lines' do
      let(:content_above_cursor) do
        <<~CODE
          # A function that outputs the first 20 fibonacci numbers

          def fibonacci(x)

        CODE
      end

      let(:content_below_cursor) do
        <<~CODE
          end

          def square_root(number)
          end
        CODE
      end

      it { is_expected.to be_small }
    end

    context 'when content around cursor is 5 or more lines' do
      let(:content_above_cursor) do
        <<~CODE
          # A function that outputs the first 20 fibonacci numbers

          def fibonacci(x)

        CODE
      end

      let(:content_below_cursor) do
        <<~CODE
          end

          # Method to calculate the square root of a number
          def square_root(number)
            if number < 0
              raise ArgumentError, "Square root of a negative number is undefined"
            else
              Math.sqrt(number)
            end
          end
        CODE
      end

      it { is_expected.not_to be_small }
    end
  end
end
