# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UserUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_user_upload_registry
end
