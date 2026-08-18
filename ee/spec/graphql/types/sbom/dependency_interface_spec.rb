# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyInterface, feature_category: :dependency_management do
  include GraphqlHelpers

  let(:fields) do
    %i[
      id
      name
      version
      componentVersion
      packager
      location
      licenses
      reachability
      malware
      vulnerability_count
      vulnerabilities
      dependencyPaths
    ]
  end

  let(:dependency) { instance_double(::Sbom::Occurrence) }

  let(:interface) do
    Class.new do
      include Types::Sbom::DependencyInterface
      attr_reader :object
      attr_reader :context

      def initialize(object, context)
        @object = object
        @context = context
      end
    end.new(dependency, query_context(user: User.new))
  end

  it { expect(described_class).to have_graphql_fields(fields) }

  describe '#packager' do
    context 'when packager is in the predefined list' do
      valid_packagers = %w[bundler npm yarn maven pip]

      valid_packagers.each do |valid_packager|
        it "returns the packager value for '#{valid_packager}'" do
          allow(dependency).to receive(:packager).and_return(valid_packager)

          expect(interface.packager).to eq(valid_packager)
        end
      end
    end

    context 'when packager is not in the predefined list' do
      it 'returns nil' do
        allow(dependency).to receive(:packager).and_return('unknown_packager')

        expect(interface.packager).to be_nil
      end
    end

    context 'when packager is nil' do
      it 'returns nil' do
        allow(dependency).to receive(:packager).and_return(nil)

        expect(interface.packager).to be_nil
      end
    end
  end

  describe '#licenses' do
    before do
      allow(dependency).to receive_messages(project_id: anything, uuid: anything)
    end

    let(:license_data) do
      [
        { 'name' => 'MIT', 'spdx_identifier' => 'MIT', 'url' => 'https://opensource.org/licenses/MIT' },
        { 'name' => 'Apache-2.0', 'spdx_identifier' => 'Apache-2.0', 'url' => 'https://www.apache.org/licenses/LICENSE-2.0' }
      ]
    end

    it 'adds occurrence context to each license' do
      allow(dependency).to receive(:licenses).and_return(license_data)

      result = interface.licenses

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first['occurrence_uuid']).to eq(dependency.uuid)
      expect(result.first['project_id']).to eq(dependency.project_id)
      expect(result.first['name']).to eq('MIT')
      expect(result.last['occurrence_uuid']).to eq(dependency.uuid)
      expect(result.last['project_id']).to eq(dependency.project_id)
      expect(result.last['name']).to eq('Apache-2.0')
    end

    context 'when licenses are not present' do
      it 'returns an empty array' do
        allow(dependency).to receive(:licenses).and_return(nil)

        expect(interface.licenses).to eq([])
      end
    end
  end

  describe '#dependency_paths' do
    let_it_be(:project) { build(:project) }
    let(:resolver) { instance_double(::Resolvers::Sbom::DependencyPathsResolver) }
    let(:ancestor) { instance_double(::Sbom::Occurrence) }
    let(:dependency_paths) do
      [
        { path: [ancestor], is_cyclic: false }
      ]
    end

    it 'returns dependency paths' do
      allow(dependency).to receive_messages(
        project: project,
        to_global_id: 'globalID'
      )

      expect(::Resolvers::Sbom::DependencyPathsResolver).to receive(:new)
        .with(object: project, context: interface.context, field: nil)
        .and_return(resolver)

      expect(resolver).to receive(:resolve)
        .with(occurrence: 'globalID')
        .and_return(dependency_paths)

      expect(interface.dependency_paths).to eq(dependency_paths)
    end
  end
end
