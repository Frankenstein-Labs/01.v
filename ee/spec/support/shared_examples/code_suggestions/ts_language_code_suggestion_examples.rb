# frozen_string_literal: true

RSpec.shared_examples 'ts language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'TypeScript' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        function add(x: number, y: number): number {
          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE,
        function greet(name: string, greeting?: string): string {
          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE,
        function power(x: number, exponent: number = 2): number {
          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE,
        const square = function (x: number): number {
          <CURSOR>
        };

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE,
        function fetchData(url: string, callback: (data: any) => void): void {
          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE,
        function identity<T>(arg: T): T {



          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
        }
      EXAMPLE

      <<~EXAMPLE
        function average(...numbers: number[]): number {
          <CURSOR>
        }

        function sub(x: number, y: number): number {
          return x - y;
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
        function add(x: number, y: number): number {
          return x + y;
        }

        function subtract(x: number, y: number): number {
          return x - y;
        }

        <CURSOR>
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
