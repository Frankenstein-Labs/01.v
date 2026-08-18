# frozen_string_literal: true

RSpec.shared_examples 'js language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'JavaScript' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        function functionName(param1, param2) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        const functionName = function() {<CURSOR>};
      EXAMPLE

      <<~EXAMPLE,
        function functionName(param1 = defaultValue) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        async function functionName(param1 = defaultValue, param2 = defaultValue) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        const functionName = function namedFunction(param1, param2) {
          <CURSOR>
        };

        function name2(param1) {
          return 2 * param1;
        }
      EXAMPLE

      <<~EXAMPLE,
        async function functionName() {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        const functionName = (callback) => {<CURSOR}
      EXAMPLE

      <<~EXAMPLE,
        function functionName() {<CURSOR>
      EXAMPLE

      <<~EXAMPLE,
        const functionName = function namedFunction() {<CURSOR>};
      EXAMPLE

      <<~EXAMPLE,
        const function functionName(param1 = defaultValue, param2 = defaultValue) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        async function functionName(param1, param2) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        function functionName(callback) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE,
        function functionName(...params) {<CURSOR>}
      EXAMPLE

      <<~EXAMPLE
        const functionName = () => {<CURSOR>};
      EXAMPLE
    ])

    with_them do
      let(:content_above_cursor) { example.split("<CURSOR>").first }
      let(:content_below_cursor) { example.split("<CURSOR>").last }

      it { is_expected.to be_truthy }
    end
  end

  context 'when cursor is inside a non-empty method' do
    let(:example) do
      <<~CONTENT
        function functionName(param1, param2) {
          let param1 = param2.toString();
          <CURSOR>

          return param1;
        }

        function functionName2(...params) {

        }
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end

  context 'when cursor is outside an empty method' do
    let(:example) do
      <<~CONTENT
        function functionName(param1, param2) {

        }

        <CURSOR>
      CONTENT
    end

    let(:content_above_cursor) { example.split("<CURSOR>").first }
    let(:content_below_cursor) { example.split("<CURSOR>").last }

    it { is_expected.to be_falsey }
  end

  context 'when language is different than the given' do
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
