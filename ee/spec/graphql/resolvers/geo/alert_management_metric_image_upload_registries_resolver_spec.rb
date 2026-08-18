# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::AlertManagementMetricImageUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_alert_management_metric_image_upload_registry
end
