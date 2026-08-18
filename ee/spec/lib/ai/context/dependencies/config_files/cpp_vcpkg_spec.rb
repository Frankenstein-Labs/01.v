# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::CppVcpkg, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('cpp')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        {
          "name": "my-project",
          "version": "1.0.3",
          "dependencies": [
            "cxxopts",
            "fmt@8.0.1#rev1",
            { "name": "boost", "version>=": "1.7.6" },
            { "name": "zlib", "default-features": false }
          ]
        }
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'cxxopts',
        'fmt (8.0.1)',
        'boost (1.7.6)',
        'zlib'
      ]
    end
  end

  context 'when the content contains test dependencies' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~CONTENT
          {
            "name": "my-project",
            "version": "1.0.3",
            "dependencies": [
              "cxxopts",
              "fmt@8.0.1#rev1",
              { "name": "boost", "version>=": "1.7.6" },
              { "name": "zlib", "default-features": false }
            ],
            "test-dependencies": [
              "poco@1.11.0",
              { "name": "sqlite3", "version>=": "3.37.0" },
              "gtest"
            ]
          }
        CONTENT
      end

      let(:expected_formatted_lib_names) do
        [
          'cxxopts',
          'fmt (8.0.1)',
          'boost (1.7.6)',
          'zlib',
          'poco (1.11.0)',
          'sqlite3 (3.37.0)',
          'gtest'
        ]
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
      'vcpkg.json'            | true
      'dir/vcpkg.json'        | true
      'dir/subdir/vcpkg.json' | true
      'dir/vcpkg'             | false
      'xvcpkg.json'           | false
      'Vcpkg.json'            | false
      'vcpkg_json'            | false
      'vcpkg'                 | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
