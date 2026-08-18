# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudArtifactRegistryArtifactsSort'], feature_category: :container_registry do
  specify { expect(described_class.graphql_name).to eq('GoogleCloudArtifactRegistryArtifactsSort') }

  it 'exposes all the existing sort values' do
    expect(described_class.values.keys).to include(
      *%w[NAME_ASC NAME_DESC IMAGE_SIZE_BYTES_ASC IMAGE_SIZE_BYTES_DESC UPLOAD_TIME_ASC UPLOAD_TIME_DESC
        BUILD_TIME_ASC BUILD_TIME_DESC UPDATE_TIME_ASC UPDATE_TIME_DESC MEDIA_TYPE_ASC MEDIA_TYPE_DESC]
    )
  end
end
