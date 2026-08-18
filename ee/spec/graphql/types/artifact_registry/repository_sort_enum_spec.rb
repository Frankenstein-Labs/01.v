# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ArtifactRegistryRepositorySort'], feature_category: :artifact_registry do
  it 'maps an ascending and a descending name to each column the list renders, and offers no others' do
    expect(described_class.values.transform_values(&:value)).to eq(
      'NAME_ASC' => { sort: 'name', order: 'asc' },
      'NAME_DESC' => { sort: 'name', order: 'desc' },
      'LAST_UPDATED_AT_ASC' => { sort: 'last_updated_at', order: 'asc' },
      'LAST_UPDATED_AT_DESC' => { sort: 'last_updated_at', order: 'desc' },
      'DOWNLOADS_COUNT_ASC' => { sort: 'downloads_count', order: 'asc' },
      'DOWNLOADS_COUNT_DESC' => { sort: 'downloads_count', order: 'desc' },
      'SIZE_BYTES_ASC' => { sort: 'size_bytes', order: 'asc' },
      'SIZE_BYTES_DESC' => { sort: 'size_bytes', order: 'desc' }
    )
  end
end
