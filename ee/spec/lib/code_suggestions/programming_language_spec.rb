# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ProgrammingLanguage, feature_category: :code_suggestions do
  describe '.detect_from_filename' do
    subject { described_class.detect_from_filename(file_name)&.name }

    described_class::SUPPORTED_LANGUAGES.each do |lang, exts|
      exts.each do |ext|
        context "for the file extension #{ext}" do
          let(:file_name) { "file.#{ext}" }

          it { is_expected.to eq(lang) }
        end
      end
    end

    context "for an unsupported language" do
      let(:file_name) { "file.nothing" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end

    context "for no file extension" do
      let(:file_name) { "file" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end

    context "for no file_name" do
      let(:file_name) { "" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end
  end

  describe '#single_line_comment_format' do
    subject { language.single_line_comment_format }

    described_class::LANGUAGE_COMMENT_FORMATS.each do |languages, format|
      languages.each do |lang|
        context "for the language #{lang}" do
          let(:language) { described_class.new(lang) }
          let(:expected_format) { format[:single_regexp] || format[:single] }

          it { is_expected.to eq(expected_format) }
        end
      end
    end

    context 'for unknown language' do
      let(:language) { described_class.new('unknown') }

      it { is_expected.to eq(described_class::DEFAULT_FORMAT[:single_regexp]) }
    end

    context 'for an unspecified language' do
      let(:language) { described_class.new('') }

      it { is_expected.to eq(described_class::DEFAULT_FORMAT[:single_regexp]) }
    end

    context 'when single_regexp is specified' do
      let(:language) { described_class.new('VBScript') }

      it 'prefers regexp to string' do
        is_expected.to be_a(Regexp)
      end
    end
  end

  describe '#single_line_comment?' do
    include_context 'with comment contents_above_cursor'

    subject { described_class.new(language).single_line_comment?(content) }

    shared_examples 'single line comment for supported language' do
      context "when it is a comment" do
        let(:content) { "#{content_above_cursor} this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when it is not a comment" do
        let(:content) { "this is not a comment " }

        it { is_expected.to be_falsey }
      end

      context "when line doesn't start with comment" do
        let(:content) { "def something() { #{content_above_cursor} this is a comment " }

        it { is_expected.to be_falsey }
      end

      context "when there is whitespace before the comment" do
        let(:content) { "      #{content_above_cursor} this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when it is a comment for different language" do
        let(:non_comment_content_above_cursor) { content_above_cursor == '#' ? '//' : '#' }
        let(:content) { "#{non_comment_content_above_cursor} this is a comment " }

        it { is_expected.to be_falsey }
      end
    end

    languages_with_single_line_comment_content_above_cursor.each do |lang, content_above_cursor|
      context "with language #{lang} and content_above_cursor #{content_above_cursor}" do
        let(:language) { lang }
        let(:content_above_cursor) { content_above_cursor }

        it_behaves_like 'single line comment for supported language'
      end
    end

    languages_missing_single_line_comments.each do |lang|
      context "with language #{lang}" do
        let(:language) { lang }

        context 'with a generic comment' do
          let(:content) { "// this is a comment " }

          it { is_expected.to be_falsey }
        end
      end
    end

    context "when the language is not supported" do
      let(:language) { 'foo' }

      context "when a common comment content_above_cursor is used" do
        let(:content) { "// this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when a special comment content_above_cursor is used" do
        let(:content) { "; this is a comment" }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#examples' do
    context 'when there is no examples defined' do
      let(:language_name) { 'noExamplesLanguage' }

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # stub SUPPORTED_LANGUAGES constant on described_class
      # to return { language_name => %w[.noex] }
      before do
        stub_const("#{described_class}::SUPPORTED_LANGUAGES", { language_name => %w[.noex] })
      end

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # generate rspec test case for #examples instance method
      # that return empty array
      it 'returns empty array when there are no examples' do
        expect(described_class.new(language_name).completion_examples).to eq([])
        expect(described_class.new(language_name).generation_examples).to eq([])
      end
    end

    # GitLab Duo code generation instruction see:
    # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
    # generate context where there is an examples for
    # language defined with language_name
    context 'when there are examples defined' do
      let(:language_name) { 'Ruby' }

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # generate one line assertion with expect that examples method
      # return array containing hashes
      # with keys: example and response
      it 'returns array of hashes with example and response' do
        expect(described_class.new(language_name).completion_examples).to all(include('example', 'response'))
        expect(described_class.new(language_name).generation_examples).to all(include('example', 'response'))
      end

      context 'when filtering generation examples by type' do
        let(:type) { 'comment' }

        subject(:examples) { described_class.new(language_name).generation_examples(type: type) }

        it 'returns only examples matching the type' do
          expect(examples).not_to be_empty
          expect(examples).to all(include('trigger_type' => type))
        end

        context 'when there are no examples for the type' do
          let(:type) { 'small_file' }

          it { is_expected.to be_empty }
        end
      end
    end
  end

  describe '#cursor_inside_empty_function?' do
    using RSpec::Parameterized::TableSyntax

    where(:language, :shared_example) do
      'Python' | 'python language'
      'Ruby' | 'ruby language'
      'Go' | 'go language'
      'JavaScript' | 'js language'
      'TypeScript' | 'ts language'
      'Java' | 'java language'
      'PHP' | 'php language'
      'C#' | 'c# language'
    end

    with_them do
      context "when language is #{params[:language]}" do
        include_examples params[:shared_example]
      end
    end
  end

  describe '#x_ray_lang' do
    using RSpec::Parameterized::TableSyntax

    where(:language, :x_ray_lang_name) do
      'C++'        | 'cpp'
      'C#'         | 'csharp'
      'Go'         | 'go'
      'Java'       | 'java'
      'JavaScript' | 'javascript'
      'Kotlin'     | 'kotlin'
      'PHP'        | 'php'
      'Python'     | 'python'
      'Ruby'       | 'ruby'
      'UNKNOWN'    | nil
    end

    with_them do
      it 'returns x_ray_lang name' do
        expect(described_class.new(language).x_ray_lang).to eq(x_ray_lang_name)
      end
    end
  end
end
