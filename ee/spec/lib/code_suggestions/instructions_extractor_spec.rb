# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::InstructionsExtractor, feature_category: :code_suggestions do
  shared_examples 'extracted instruction' do
    it 'sets create instruction and trigger_type', :aggregate_failures do
      expect(subject.instruction).to eq(instruction)
      expect(subject.trigger_type).to eq(trigger_type)
    end
  end

  describe '.extract' do
    let(:language) do
      CodeSuggestions::ProgrammingLanguage.new(CodeSuggestions::ProgrammingLanguage::DEFAULT_NAME)
    end

    let(:instruction) do
      <<~PROMPT
        Create more new code for this file. If the cursor is inside an empty function,
        generate its most likely contents based on the function name and signature.
      PROMPT
    end

    let(:content_below_cursor) { '' }
    let(:file_content) { CodeSuggestions::FileContent.new(language, content_above_cursor, content_below_cursor) }
    let(:intent) { nil }
    let(:generation_type) { nil }
    let(:user_instruction) { nil }

    subject do
      described_class.new(file_content, intent, generation_type, user_instruction).extract
    end

    context 'when content_above_cursor is nil' do
      let(:content_above_cursor) { nil }

      it_behaves_like 'extracted instruction' do
        let(:trigger_type) { 'small_file' }
      end
    end

    context 'when language is not supported' do
      let(:language) { CodeSuggestions::ProgrammingLanguage.new('foo') }
      let(:content_above_cursor) do
        <<~CODE
          full_name()
          address()
          street()
          city()
          state()
          pincode()

          #{comment_sign}Generate me a function
          #{comment_sign}with 2 arguments
        CODE
      end

      context 'when content_above_cursor uses generic prefix sign' do
        let(:comment_sign) { '#' }

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when content_above_cursor uses special prefix sign' do
        let(:comment_sign) { '!' }

        it { is_expected.to be_nil }
      end
    end

    context 'when there is instruction' do
      let(:content_above_cursor) do
        <<~CODE
          # Generate me a function
        CODE
      end

      it_behaves_like 'extracted instruction' do
        let(:instruction) { '' }
        let(:trigger_type) { 'comment' }
      end

      context 'when intent is completion' do
        let(:intent) { 'completion' }

        it { is_expected.to be_nil }
      end
    end

    context 'when there is no instruction' do
      let(:content_above_cursor) do
        <<~CODE
          full_name()
          address()
          street()
          city()
          state()
          pincode()
        CODE
      end

      it { is_expected.to be_nil }

      context 'when generation_type is set' do
        let(:generation_type) { 'comment' }

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when intent is generation' do
        let(:intent) { 'generation' }

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end
    end

    context 'when there is a user instruction' do
      let(:content_above_cursor) { '' }
      let(:user_instruction) { 'Generate me a hello world function' }

      it_behaves_like 'extracted instruction' do
        let(:instruction) { user_instruction }
        let(:trigger_type) { nil }
      end
    end

    shared_examples_for 'detects comments correctly' do
      context 'when there is only one comment line' do
        let(:content_above_cursor) do
          <<~CODE
            #{comment_sign}Generate me a function
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when the comment is too short' do
        let(:content_above_cursor) do
          <<~CODE
            #{comment_sign}Generate
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:trigger_type) { 'small_file' }
        end
      end

      context 'when the last line is not a comment but code is less than 5 lines' do
        let(:content_above_cursor) do
          <<~CODE
            #{comment_sign}A function that outputs the first 20 fibonacci numbers

            def fibonacci(x)

          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:trigger_type) { 'small_file' }
        end
      end

      context 'when there are some lines above the comment' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when there are several comment in a row' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when there are several comments in a row followed by empty line' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last\n
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:instruction) { '' }
          let(:trigger_type) { 'comment' }
        end
      end

      context 'when there are several comments in a row followed by empty lines' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last


          CODE
        end

        it { is_expected.to be_nil }
      end

      context 'when there are several comments in a row followed by other code' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
            other_code()
          CODE
        end

        it { is_expected.to be_nil }
      end

      context 'when the first line of multiline comment does not meet requirements' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()

            #{comment_sign}Generate
            #{comment_sign}me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
          CODE
        end

        let(:expected_content_above_cursor) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()
          CODE
        end

        it_behaves_like 'extracted instruction' do
          let(:trigger_type) { 'small_file' }
        end
      end

      context 'when there is content_above_cursor between comment lines' do
        let(:content_above_cursor) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()


            #{comment_sign}just some comment
            #{comment_sign}explaining something

            #{comment_sign}Generate
          CODE
        end

        it "does not find instruction" do
          is_expected.to be_nil
        end
      end
    end

    context 'when content_above_cursor is a supported language' do
      include_context 'with comment contents_above_cursor'

      languages_with_single_line_comment_content_above_cursor.each do |lang, content_above_cursor|
        context "when using language #{lang} and content_above_cursor #{content_above_cursor}" do
          let(:language) { CodeSuggestions::ProgrammingLanguage.new(lang) }
          let(:comment_sign) { content_above_cursor }

          it_behaves_like 'detects comments correctly'
        end
      end
    end

    context 'when cursor is inside an empty method' do
      let(:language) do
        CodeSuggestions::ProgrammingLanguage.new('Python')
      end

      let(:instruction) do
        <<~INSTRUCTION
          Complete the empty function and generate contents based on the function name and signature.
          Do not repeat the code. Only return the method contents.
        INSTRUCTION
      end

      let(:content_above_cursor) do
        <<~CONTENT_ABOVE_CURSOR
          def func0():
            return 0

          def func2():
            return 0

          def func1():
            return 0

          def index(arg1, arg2):

        CONTENT_ABOVE_CURSOR
      end

      context 'when it is at the end of the file' do
        let(:content_below_cursor) { '' }

        it_behaves_like 'extracted instruction' do
          let(:trigger_type) { 'empty_function' }
        end
      end

      context 'when cursor is inside an empty method but middle of the file' do
        let(:content_below_cursor) do
          <<~SUFFIX
            def index2():
              return 0

            def index3(arg1):
              return 1
          SUFFIX
        end

        it_behaves_like 'extracted instruction' do
          let(:trigger_type) { 'empty_function' }
        end
      end

      context 'when cursor in inside a non-empty method' do
        let(:content_below_cursor) do
          <<~SUFFIX
              return 0

            def index2():
              return 'something'
          SUFFIX
        end

        it { is_expected.to be_nil }
      end
    end
  end
end
