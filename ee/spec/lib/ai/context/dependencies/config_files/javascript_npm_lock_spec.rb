# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::JavascriptNpmLock, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('javascript')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~JSON
        {
          "name": "countly-server",
          "version": "24.5.0",
          "lockfileVersion": 3,
          "requires": true,
          "packages": {
            "": {
              "name": "countly-server",
              "version": "24.5.0"
            },
            "api/utils/countly-root": {
              "version": "0.1.0"
            },
            "node_modules/@babel/core/node_modules/convert-source-map": {
              "version": "2.0.0",
              "resolved": "https://registry.npmjs.org/...",
              "integrity": "sha512-...",
              "dev": true,
              "license": "MIT"
            },
            "node_modules/@babel/test-package": {
              "version": "1.2.3",
              "resolved": "https://registry.npmjs.org/...",
              "integrity": "sha512-...",
              "dev": true,
              "license": "MIT"
            }
          }
        }
      JSON
    end

    let(:expected_formatted_lib_names) do
      ['babel/core/node_modules/convert-source-map (2.0.0)', 'babel/test-package (1.2.3)']
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid JSON' }
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'package-lock.json'             | true
      'dir/package-lock.json'         | true
      'dir/subdir/package-lock.json'  | true
      'dir/package.json'              | false
      'Package-lock.json'             | false
      'package_lock.json'             | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
