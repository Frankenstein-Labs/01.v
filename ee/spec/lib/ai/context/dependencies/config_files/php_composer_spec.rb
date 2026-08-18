# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PhpComposer, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('php')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~JSON
        {
          "name": "composer/composer",
          "type": "library",
          "description": "Composer helps you declare, manage and install dependencies of PHP projects. It ensures you have the right stack everywhere.",
          "keywords": [
            "package",
            "dependency",
            "autoload"
          ],
          "require": {
            "ext-pcre": "*",
            "php": "^7.2 || ^8.0"
          }
        }
      JSON
    end

    let(:expected_formatted_lib_names) do
      ['ext-pcre (*)', 'php (^7.2 || ^8.0)']
    end
  end

  context 'when the content contains dev dependencies' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~JSON
          {
            "name": "composer/composer",
            "type": "library",
            "description": "Composer helps you declare, manage and install dependencies of PHP projects. It ensures you have the right stack everywhere.",
            "keywords": [
              "package",
              "dependency",
              "autoload"
            ],
            "require": {
              "ext-pcre": "*",
              "php": "^7.2 || ^8.0"
            },
            "require-dev": {
              "phpstan/phpstan": "^1.10",
              "psr/log": "^1.0 || ^2.0 || ^3.0"
            }
          }
        JSON
      end

      let(:expected_formatted_lib_names) do
        ['ext-pcre (*)', 'php (^7.2 || ^8.0)', 'phpstan/phpstan (^1.10)', 'psr/log (^1.0 || ^2.0 || ^3.0)']
      end
    end
  end

  context 'when config file content is an array' do
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
      'composer.json'             | true
      'dir/composer.json'         | true
      'dir/subdir/composer.json'  | true
      'dir/composer.js'           | false
      'Composer.json'             | false
      'composer_json'             | false
      'composer.lock'             | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
