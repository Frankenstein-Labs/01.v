# frozen_string_literal: true

RSpec.shared_examples 'python language' do
  let(:language_name) { 'Python' }

  subject do
    described_class.new(language_name).cursor_inside_empty_function?(content_above_cursor, content_below_cursor)
  end

  context 'when the cursor is at the end of the file' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def func1():
          return 0

        def index(arg1, arg2):

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) { '' }

    it { is_expected.to be_truthy }
  end

  context 'when cursor is inside an empty method but middle of the file' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def func1():

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) do
      <<~CONTENT_BELOW_CURSOR
        def index2():
          return 0

        def index3(arg1):
          return 1
      CONTENT_BELOW_CURSOR
    end

    it { is_expected.to be_truthy }
  end

  context 'when cursor in inside a non-empty method' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def func1():

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) do
      <<~CONTENT_BELOW_CURSOR
          return 0

        def index2():
          return 'something'
      CONTENT_BELOW_CURSOR
    end

    it { is_expected.to be_falsey }
  end

  context 'when cursor inside class method' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        class User(Base):
          def __init__(self, f_name, l_name):
            self.f_name = f_name
            self.l_name = l_name

          def full_name(self):

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) { '' }

    it { is_expected.to be_truthy }
  end

  context 'when cursor inside the method with multiple spaces' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def func1():



      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) do
      <<~CONTENT_BELOW_CURSOR
        def index2():
          return 0

        def index3(arg1):
          return 1
      CONTENT_BELOW_CURSOR
    end

    it { is_expected.to be_truthy }
  end

  context 'when cursor is inside an empty method with comments' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def index4(arg1, arg2):
          return 1

        def func1():

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) do
      <<~CONTENT_BELOW_CURSOR
        def index2():
          return 0

        def index3(arg1):
          return 1
      CONTENT_BELOW_CURSOR
    end

    it { is_expected.to be_truthy }
  end

  context 'when language in different that the given' do
    let(:content_above_cursor) do
      <<~CONTENT_ABOVE_CURSOR
        def index4(arg1, arg2)
          return 1
        end

        def func1

      CONTENT_ABOVE_CURSOR
    end

    let(:content_below_cursor) do
      <<~CONTENT_BELOW_CURSOR
        def index2
          return 0
        end

        def index3(arg1)
          return 1
        end
      CONTENT_BELOW_CURSOR
    end

    it { is_expected.to be_falsey }
  end
end
