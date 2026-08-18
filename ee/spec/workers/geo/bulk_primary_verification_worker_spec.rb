# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkPrimaryVerificationWorker, :geo, feature_category: :geo_replication do
  it_behaves_like 'a Geo bulk update worker', model_name: 'Upload', service: Geo::BulkPrimaryVerificationService
end
