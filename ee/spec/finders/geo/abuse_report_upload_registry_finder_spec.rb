# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AbuseReportUploadRegistryFinder, feature_category: :geo_replication do
  it_behaves_like 'a framework registry finder', :geo_abuse_report_upload_registry
end
