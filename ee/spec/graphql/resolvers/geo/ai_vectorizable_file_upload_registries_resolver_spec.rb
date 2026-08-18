# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::AiVectorizableFileUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_ai_vectorizable_file_upload_registry
end
