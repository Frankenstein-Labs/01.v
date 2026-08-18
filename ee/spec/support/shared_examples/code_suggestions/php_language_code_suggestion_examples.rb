# frozen_string_literal: true

RSpec.shared_examples 'php language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'PHP' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        function greetUser($name, $timeOfDay) {
          <CURSOR>
        }

        function addNumbers($num1, $num2) {
          return $num1 + $num2;
        }
      EXAMPLE

      <<~EXAMPLE,
        function calculateArea(float $radius): float {
          <CURSOR>
        }

        function getNumbers() {
          return $num1;
        }
      EXAMPLE

      <<~EXAMPLE,
        function sumValues(...$numbers) {
          <CURSOR>
        }

        function calculateArea(float $radius): float {
          return $radius;
        }
      EXAMPLE

      <<~EXAMPLE,
        $calculateSquare = function($number) {
          <CURSOR>
        };

        function addNumbers($num1, $num2) {
          return $num1 + $num2;
        }
      EXAMPLE

      <<~EXAMPLE,
        class MathUtils {
          public static function multiply($num1, $num2) {
              <CURSOR>
          }

          function addNumbers($num1, $num2) {
            return $num1 + $num2;
          }
        }
      EXAMPLE

      <<~EXAMPLE
        function calculateTotalPrice(float $price, int $quantity) {
          <CURSOR>
        }

        function addNumbers($num1, $num2) {
          return $num1 + $num2;
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
        function greetUser($name, $timeOfDay) {
          <CURSOR>

          return $num1 + $num2;
        }

        function addNumbers($num1, $num2) {
          return $num1 + $num2;
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
