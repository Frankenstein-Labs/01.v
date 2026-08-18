# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Sbom::CyclonedxMetadataComponent, feature_category: :dependency_management do
  let(:name) { 'Root Application' }
  let(:type) { 'application' }
  let(:ref) { 'bom-ref' }

  describe "#parse_component" do
    subject(:component) { described_class.new(data).parse_component }

    %w[name type bom-ref].each do |property|
      context "without #{property}" do
        let(:data) { { 'name' => name, 'type' => type, 'bom-ref' => ref }.except(property) }

        it 'returns nil' do
          expect(component).to be_nil
        end
      end
    end

    context 'with all required properties' do
      let(:data) { { 'name' => name, 'type' => type, 'bom-ref' => ref } }

      it 'returns a sbom component' do
        expect(component).to be_kind_of(::Gitlab::Ci::Reports::Sbom::Component)

        expect(component.component_type).to eq(type)
        expect(component.name).to eq(name)
        expect(component.ref).to eq(ref)
      end
    end
  end

  describe '#parse_files' do
    subject(:files) { described_class.new(data).parse_files }

    context 'when properties are nil' do
      let(:data) { nil }

      it 'returns an empty array' do
        expect(files).to be_empty
      end
    end

    context 'when components key is absent' do
      let(:data) { { 'name' => name, 'type' => type, 'bom-ref' => ref } }

      it 'returns an empty array' do
        expect(files).to be_empty
      end
    end

    context 'when components is an empty array' do
      let(:data) { { 'name' => name, 'type' => type, 'bom-ref' => ref, 'components' => [] } }

      it 'returns an empty array' do
        expect(files).to be_empty
      end
    end

    context 'when components contain non-file type entries' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            { 'type' => 'library',
              'name' => 'some-lib',
              'bom-ref' => 'pkg:gem/some-lib@1.0',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'requirements' }
              ] }
          ]
        }
      end

      it 'ignores non-file components' do
        expect(files).to be_empty
      end
    end

    context 'when a file component has no name' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            { 'type' => 'file',
              'bom-ref' => 'file:unnamed',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'requirements' }
              ] }
          ]
        }
      end

      it 'ignores file components without a name' do
        expect(files).to be_empty
      end
    end

    context 'when file components have no gitlab properties' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            { 'type' => 'file', 'name' => 'subdir1/Gemfile', 'bom-ref' => 'file:subdir1/Gemfile' }
          ]
        }
      end

      it 'ignores file components' do
        expect(files).to be_empty
      end
    end

    context 'when a file component has an unrecognised type value' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'subdir1/Gemfile',
              'bom-ref' => 'file:subdir1/Gemfile',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'unknown_type' }
              ]
            }
          ]
        }
      end

      it 'ignores file components with unrecognised types' do
        expect(files).to be_empty
      end
    end

    context 'when a file component has invalid properties' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            { 'type' => 'file',
              'name' => 'subdir1/Gemfile',
              'bom-ref' => 'file:unnamed',
              'properties' => [
                { 'name' => 'custom:file:type', 'value' => 'requirements' }
              ] }
          ]
        }
      end

      it 'ignores file components with invalid properties' do
        expect(files).to be_empty
      end
    end

    context 'when a file component has a property with a nil name' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'Gemfile',
              'bom-ref' => 'file:Gemfile',
              'properties' => [
                { 'name' => nil, 'value' => 'requirements' },
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'requirements' }
              ]
            }
          ]
        }
      end

      it 'ignores properties with nil names' do
        expect(files).to eq([
          { 'path' => 'Gemfile', 'type' => 'requirements' }
        ])
      end
    end

    context 'when file components have full gitlab properties' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'subdir1/Gemfile',
              'bom-ref' => 'file:subdir1/Gemfile',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'requirements' },
                { 'name' => 'gitlab:dependency_scanning:file:in_repository', 'value' => 'true' }
              ]
            },
            {
              'type' => 'file',
              'name' => 'subdir1/Gemfile.lock',
              'bom-ref' => 'file:subdir1/Gemfile.lock',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'lockfile' },
                { 'name' => 'gitlab:dependency_scanning:file:in_repository', 'value' => 'true' }
              ]
            }
          ]
        }
      end

      it 'returns all file entries with path, type and in_repository' do
        expect(files).to eq([
          { 'path' => 'subdir1/Gemfile',      'type' => 'requirements', 'in_repository' => true },
          { 'path' => 'subdir1/Gemfile.lock', 'type' => 'lockfile',     'in_repository' => true }
        ])
      end
    end

    context 'when file components cover all valid types' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'requirements.txt',
              'bom-ref' => 'file:requirements.txt',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'requirements' }
              ]
            },
            {
              'type' => 'file',
              'name' => 'Gemfile.lock',
              'bom-ref' => 'file:Gemfile.lock',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'lockfile' }
              ]
            },
            {
              'type' => 'file',
              'name' => 'package-lock.json',
              'bom-ref' => 'file:package-lock.json',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'graphfile' }
              ]
            }
          ]
        }
      end

      it 'returns entries for all three valid types' do
        expect(files).to eq([
          { 'path' => 'requirements.txt',  'type' => 'requirements' },
          { 'path' => 'Gemfile.lock',      'type' => 'lockfile' },
          { 'path' => 'package-lock.json', 'type' => 'graphfile' }
        ])
      end
    end

    context 'when in_repository value is false' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'vendor/Gemfile.lock',
              'bom-ref' => 'file:vendor/Gemfile.lock',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'lockfile' },
                { 'name' => 'gitlab:dependency_scanning:file:in_repository', 'value' => 'false' }
              ]
            }
          ]
        }
      end

      it 'coerces in_repository to false' do
        expect(files).to eq([
          { 'path' => 'vendor/Gemfile.lock', 'type' => 'lockfile', 'in_repository' => false }
        ])
      end
    end

    context 'when components mix file and non-file types' do
      let(:data) do
        {
          'name' => name, 'type' => type, 'bom-ref' => ref,
          'components' => [
            {
              'type' => 'file',
              'name' => 'subdir1/Gemfile.lock',
              'bom-ref' => 'file:subdir1/Gemfile.lock',
              'properties' => [
                { 'name' => 'gitlab:dependency_scanning:file:type', 'value' => 'lockfile' },
                { 'name' => 'gitlab:dependency_scanning:file:in_repository', 'value' => 'true' }
              ]
            },
            {
              'type' => 'library',
              'name' => 'rails',
              'bom-ref' => 'pkg:gem/rails@7.0.0'
            }
          ]
        }
      end

      it 'returns only the file entries' do
        expect(files).to eq([
          { 'path' => 'subdir1/Gemfile.lock', 'type' => 'lockfile', 'in_repository' => true }
        ])
      end
    end
  end
end
