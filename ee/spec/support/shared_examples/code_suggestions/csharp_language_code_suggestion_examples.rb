# frozen_string_literal: true

RSpec.shared_examples 'c# language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'C#' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        static int AddNumbers(int num1, int num2) {
            <CURSOR>
        }

        static int SubtractNumbers(int num1, int num2) {
            return num1 - num2;
        }
      EXAMPLE

      <<~EXAMPLE,
        static int SumValues(params int[] numbers)
        {
            <CURSOR>

        static int SubValues(params int[] numbers)
        {
            return numbers.Sub();
        }
      EXAMPLE

      <<~EXAMPLE
        class MathUtils
        {
            public static int Multiply(int num1, int num2)
            {
                <CURSOR>
            }
        }
      EXAMPLE
    ])

    with_them do
      let(:content_above_cursor) { example.split("<CURSOR>").first }
      let(:content_below_cursor) { example.split("<CURSOR>").last }

      it { is_expected.to be_truthy }
    end
  end

  context 'when cursor is outside an empty method' do
    let(:example) do
      <<~CONTENT
        static int AddNumbers(int num1, int num2)
        {
          <CURSOR>
          return num1 + num2;
        }

        static string GreetUser(string name, string timeOfDay)
        {
            return $"Good {timeOfDay}, {name}!";
        }
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end

  context 'when language is different that the given' do
    let(:example) do
      <<~CONTENT
        def index4(arg1, arg2):
          return 1

        def func1():
          <CURSOR>

        def index2():
          return 0

        def index3(arg1):
          return 1
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end
end
