# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AlertManagementMetricImageUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_alert_management_metric_image_upload_registry
end
