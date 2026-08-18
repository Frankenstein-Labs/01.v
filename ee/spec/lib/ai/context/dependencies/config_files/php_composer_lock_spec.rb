# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PhpComposerLock, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('php')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) { File.read('ee/spec/fixtures/lib/ai/context/dependencies/config_files/composer.lock') }
    let(:expected_formatted_lib_names) do
      ['composer/ca-bundle (1.5.1)', 'composer/metadata-minifier (1.0.0)', 'lib/with-integer-version (20240308)']
    end
  end

  context 'when the content is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '[]' }
      let(:expected_error_class_name) { 'ParsingErrors::UnexpectedNodeError' }
      let(:expected_error_message) { 'encountered unexpected node' }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid JSON' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'composer.lock'             | true
      'dir/composer.lock'         | true
      'dir/subdir/composer.lock'  | true
      'dir/composer.loc'          | false
      'Composer.lock'             | false
      'composer_lock'             | false
      'composer.json'             | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
