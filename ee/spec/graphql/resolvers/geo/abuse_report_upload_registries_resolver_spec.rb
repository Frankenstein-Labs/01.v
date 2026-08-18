# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::AbuseReportUploadRegistriesResolver, feature_category: :geo_replication do
  it_behaves_like 'a Geo registries resolver', :geo_abuse_report_upload_registry
end
