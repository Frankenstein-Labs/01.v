# frozen_string_literal: true

RSpec.shared_examples 'java language' do
  using RSpec::Parameterized::TableSyntax

  let(:language_name) { 'Java' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when various variations of empty functions are used' do
    where(example: [
      <<~EXAMPLE,
        int calculateSum(int a, int b) {
          <CURSOR>
        }

        public staic void main(System s) {
          System.out.println("Hello");
        }
      EXAMPLE

      <<~EXAMPLE,
        public String concatString(String str1, String str2) {
          <CURSOR>
        }

        void pring(String s) {
          System.out.println(s);
        }
      EXAMPLE

      <<~EXAMPLE,
        boolean isEven(int num) {
          <CURSOR>

        void print(String s) {

        }
      EXAMPLE

      <<~EXAMPLE
        public class Main {
          public Person(String name) {
            <CURSOR>
          }

          public void setName(String name) {
            this.name = name;
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
        String getString(char c) {
          return c;
        }

        void setString(String s) {
          // This is a doc string in Java
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
