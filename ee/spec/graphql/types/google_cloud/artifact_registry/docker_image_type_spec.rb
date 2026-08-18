# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudArtifactRegistryDockerImage'], feature_category: :container_registry do
  specify do
    expect(described_class.description).to eq('Represents a docker artifact of Google Artifact Registry')
  end

  it 'includes all expected fields' do
    expected_fields = %w[name tags upload_time update_time image digest uri]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
