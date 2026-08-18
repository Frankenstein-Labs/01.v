# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudArtifactRegistryDockerImageDetails'], feature_category: :container_registry do
  specify do
    expect(described_class.description)
      .to eq('Represents details about docker artifact of Google Artifact Registry')
  end

  it 'includes all expected fields' do
    expected_fields = %w[
      name tags image_size_bytes upload_time
      media_type build_time update_time project_id
      location repository image digest artifact_registry_image_url
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
