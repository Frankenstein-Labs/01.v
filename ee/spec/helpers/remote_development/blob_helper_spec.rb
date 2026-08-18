# frozen_string_literal: true

require_relative 'helper_shared_examples'

RSpec.describe RemoteDevelopment::BlobHelper, feature_category: :workspaces do
  include_examples "workspace_helper_data", helper_method: :vue_blob_workspace_data
end
