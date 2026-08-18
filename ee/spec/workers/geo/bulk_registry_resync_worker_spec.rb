# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkRegistryResyncWorker, :geo, feature_category: :geo_replication do
  it_behaves_like 'a Geo bulk update worker',
    model_name: 'Geo::JobArtifactRegistry',
    service: Geo::BulkRegistryResyncService
end
