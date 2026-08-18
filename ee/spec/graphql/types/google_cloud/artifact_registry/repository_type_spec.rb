# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudArtifactRegistryRepository'], feature_category: :container_registry do
  specify do
    expect(described_class.description).to eq('Represents a repository of Google Artifact Registry')
  end

  it 'includes all expected fields' do
    expected_fields = %w[project_id repository artifact_registry_repository_url artifacts]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_google_cloud_artifact_registry) }
end
