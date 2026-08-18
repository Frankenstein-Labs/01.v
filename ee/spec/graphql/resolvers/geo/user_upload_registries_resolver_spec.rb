# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::UserUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_user_upload_registry
end
