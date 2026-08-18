# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::OutputParser,
  feature_category: :dependency_management do
  def load_output_fixture(name)
    File.read(Rails.root.join("ee/spec/fixtures/dependency_management/#{name}.json"))
  end

  describe '.parse' do
    let(:raw_json) { "" }

    subject(:parsed_output) { described_class.parse(raw_json) }

    context 'with a valid output' do
      let(:raw_json) { load_output_fixture('output_valid') }

      it 'parses dependencies' do
        expect(parsed_output.dependencies.size).to eq(1)

        dep = parsed_output.dependencies.first
        expect(dep.name).to eq('rack')
        expect(dep.version).to eq('2.2.0')
        expect(dep.previous_version).to eq('2.0.9')
      end

      it 'parses updated files' do
        expect(parsed_output.updated_files.size).to eq(2)
        expect(parsed_output.updated_files.map(&:path)).to contain_exactly('Gemfile', 'Gemfile.lock')
      end

      it 'defaults encoding to text' do
        expect(parsed_output.updated_files.first.encoding).to eq('text')
      end
    end

    context 'with multiple dependency_updates' do
      let(:raw_json) { load_output_fixture('output_multiple_deps') }

      it 'parses all dependencies' do
        expect(parsed_output.dependencies.map(&:name)).to contain_exactly('rack', 'rake')
      end
    end

    context 'with directory traversal in file paths' do
      let(:raw_json) { load_output_fixture('output_traversal') }

      it 'rejects traversal and absolute paths' do
        expect(parsed_output.updated_files.map(&:path)).to contain_exactly('valid/Gemfile', 'another/path/Gemfile')
      end
    end

    context 'with entries missing required fields' do
      let(:raw_json) { load_output_fixture('output_missing_required_fields') }

      it 'skips entries with missing required fields' do
        expect(parsed_output.dependencies.map(&:name)).to eq(['valid'])
        expect(parsed_output.updated_files.map(&:path)).to eq(['path/valid.txt'])
      end
    end

    context 'with missing keys' do
      it 'returns empty arrays when dependency_updates key is absent' do
        output = described_class.parse({ 'updated_files' => [] }.to_json)
        expect(output.dependencies).to be_empty
      end

      it 'returns empty arrays when updated_files key is absent' do
        output = described_class.parse({ 'dependency_updates' => [] }.to_json)
        expect(output.updated_files).to be_empty
      end
    end

    context 'with invalid JSON' do
      it 'raises a ParseError' do
        expect { described_class.parse('not json') }
          .to raise_error(described_class::ParseError, /Invalid JSON/)
      end
    end

    context 'with a non-object JSON root' do
      it 'raises a ParseError' do
        expect { described_class.parse('"just a string"') }
          .to raise_error(described_class::ParseError, /must be a JSON object/)
      end
    end
  end
end
