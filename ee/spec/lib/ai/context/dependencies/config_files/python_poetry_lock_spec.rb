# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PythonPoetryLock, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('python')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) { File.read('ee/spec/fixtures/lib/ai/context/dependencies/config_files/poetry.lock') }
    let(:expected_formatted_lib_names) { ['anthropic (0.28.1)', 'anyio (4.4.0)'] }
  end

  context 'when the content is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '[]' }
      let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
      let(:expected_error_message) { 'content is not valid TOML' }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid TOML' }
  end

  context 'when the content contains duplicate keys' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:config_file_content) do
        <<~TOML
          [[package]]
          name = "anthropic"
          version = "0.28.1"
          version = "1.2.3"
        TOML
      end

      let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
      let(:expected_error_message) { 'error parsing TOML: Key "version" is defined more than once' }
    end
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'poetry.lock'             | true
      'dir/poetry.lock'         | true
      'dir/subdir/poetry.lock'  | true
      'dir/poetry.loc'          | false
      'poetry_lock'             | false
      'Poetry.lock'             | false
      'pyproject.toml'          | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
