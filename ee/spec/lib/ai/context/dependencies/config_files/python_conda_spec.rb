# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PythonConda, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('python')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~YAML
        name: machine-learning-env

        dependencies:
          - ipython
          - scikit-learn=0.22
      YAML
    end

    let(:expected_formatted_lib_names) { ['ipython', 'scikit-learn (0.22)'] }
  end

  context 'when the content is an array' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '[]' }
      let(:expected_error_class_name) { 'ParsingErrors::UnexpectedNodeError' }
      let(:expected_error_message) { 'encountered unexpected node' }
    end
  end

  context 'when the content is an invalid string' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '*' }
      let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
      let(:expected_error_message) { 'content is not valid YAML' }
    end
  end

  context 'when the content contains a YAML Date value' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) do
        <<~YAML
          name: machine-learning-env
          my_date: 2024-01-01
        YAML
      end

      let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
      let(:expected_error_message) { 'YAML exception - Tried to load unspecified class: Date' }
    end
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'environment.yml'             | true
      'dir/environment.yml'         | true
      'dir/subdir/environment.yml'  | true
      'dir/environment.ym'          | false
      'Environment.yml'             | false
      'environment_yml'             | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
