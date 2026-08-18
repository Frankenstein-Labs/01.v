# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::JavascriptNpm, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('javascript')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~JSON
        {
          "name": "countly-server",
          "version": "24.5.0",
          "dependencies": {
            "all-the-cities": "3.1.0",
            "argon2": "0.41.1",
            "countly-request": "file:api/utils/countly-request",
            "lib-with-no-version": null
          }
        }
      JSON
    end

    let(:expected_formatted_lib_names) do
      ['all-the-cities (3.1.0)', 'argon2 (0.41.1)', 'lib-with-no-version']
    end
  end

  context 'when the content contains dev dependencies' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~JSON
          {
            "name": "countly-server",
            "version": "24.5.0",
            "devDependencies": {
              "apidoc": "^1.0.1"
            },
            "dependencies": {
              "all-the-cities": "3.1.0",
              "argon2": "0.41.1",
              "countly-request": "file:api/utils/countly-request"
            }
          }
        JSON
      end

      let(:expected_formatted_lib_names) do
        ['apidoc (^1.0.1)', 'all-the-cities (3.1.0)', 'argon2 (0.41.1)']
      end
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid JSON' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'package.json'             | true
      'dir/package.json'         | true
      'dir/subdir/package.json'  | true
      'dir/package-lock.json'    | false
      'Package.json'             | false
      'package_json'             | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
