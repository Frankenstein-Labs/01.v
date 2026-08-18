# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AiVectorizableFileUploadReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:geo_ai_vectorizable_file_upload) }

  include_examples 'a blob replicator with a read-only replicable model'
  include_examples 'a blob replicator with upload replicator behavior'
end
