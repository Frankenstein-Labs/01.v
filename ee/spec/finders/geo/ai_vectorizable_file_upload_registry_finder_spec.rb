# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AiVectorizableFileUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_ai_vectorizable_file_upload_registry
end
