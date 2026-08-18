# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenUpstreamCacheEntry'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) do
    %i[
      id
      relative_path
      size
      file_sha1
      file_md5
      content_type
      upstream_etag
      downloads_count
      created_at
      updated_at
      downloaded_at
      upstream_checked_at
    ]
  end

  it 'uses CountableConnectionType' do
    expect(described_class.connection_type_class).to eq(::Types::CountableConnectionType)
  end

  it { is_expected.to have_graphql_fields(fields) }
end
