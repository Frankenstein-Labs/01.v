# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ArtifactRegistryRepository'], feature_category: :artifact_registry do
  using RSpec::Parameterized::TableSyntax

  subject { described_class }

  specify { expect(described_class.graphql_name).to eq('ArtifactRegistryRepository') }

  it { is_expected.to require_graphql_authorizations(:read_artifact_registry) }

  it 'exposes the list fields plus the read fields the edit prefill needs' do
    is_expected.to have_graphql_fields(
      :name, :format, :kind, :visibility, :downloads_count, :size_bytes, :last_updated_at,
      :description, :settings
    )
  end

  describe 'field types' do
    where(:field_name, :type_name) do
      'name'           | 'String'
      'format'         | 'ArtifactRegistryRepositoryFormat'
      'kind'           | 'ArtifactRegistryRepositoryKind'
      'visibility'     | 'ArtifactRegistryRepositoryVisibility'
      'downloadsCount' | 'BigInt'
      'sizeBytes'      | 'BigInt'
      'lastUpdatedAt'  | 'Time'
      'description'    | 'String'
      'settings'       | 'JSON'
    end

    with_them do
      it 'renders the field as the declared type' do
        expect(described_class.fields[field_name].type.unwrap.graphql_name).to eq(type_name)
      end
    end
  end

  it 'leaves lastUpdatedAt nullable, because a repository whose content never changed reports none' do
    expect(described_class.fields['lastUpdatedAt'].type).to be_nullable
  end

  it 'marks every field experiment ahead of general availability' do
    expect(described_class.fields.values)
      .to all(have_attributes(deprecation_reason: a_string_including('Status: Experiment.')))
  end

  describe 'the format enum' do
    let(:enum) { described_class.fields['format'].type.unwrap }

    where(:artifact_registry_value, :graphql_value) do
      'docker' | 'DOCKER'
      'oci'    | 'OCI'
      'maven'  | 'MAVEN'
      'npm'    | 'NPM'
    end

    with_them do
      it 'decodes the Artifact Registry format' do
        expect(enum.coerce_isolated_result(artifact_registry_value)).to eq(graphql_value)
      end
    end

    it 'declares no value outside the Artifact Registry contract' do
      expect(enum.values.keys).to contain_exactly('DOCKER', 'OCI', 'MAVEN', 'NPM')
    end
  end

  describe 'the kind enum' do
    let(:enum) { described_class.fields['kind'].type.unwrap }

    where(:artifact_registry_value, :graphql_value) do
      'hosted'  | 'HOSTED'
      'virtual' | 'VIRTUAL'
      'remote'  | 'REMOTE'
    end

    with_them do
      it 'decodes the Artifact Registry kind' do
        expect(enum.coerce_isolated_result(artifact_registry_value)).to eq(graphql_value)
      end
    end

    it 'declares no value outside the Artifact Registry contract' do
      expect(enum.values.keys).to contain_exactly('HOSTED', 'VIRTUAL', 'REMOTE')
    end
  end

  describe 'the visibility enum' do
    let(:enum) { described_class.fields['visibility'].type.unwrap }

    where(:artifact_registry_value, :graphql_value) do
      'private'  | 'PRIVATE'
      'internal' | 'INTERNAL'
      'public'   | 'PUBLIC'
    end

    with_them do
      it 'decodes the Artifact Registry visibility' do
        expect(enum.coerce_isolated_result(artifact_registry_value)).to eq(graphql_value)
      end
    end

    it 'declares no value outside the Artifact Registry contract' do
      expect(enum.values.keys).to contain_exactly('PRIVATE', 'INTERNAL', 'PUBLIC')
    end
  end
end
