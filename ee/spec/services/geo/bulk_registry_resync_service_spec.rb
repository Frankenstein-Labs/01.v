# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkRegistryResyncService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:model_name) { 'Geo::JobArtifactRegistry' }
  let(:registry_states) { registry_class::STATE_VALUES }
  let(:worker) { Geo::BulkRegistryResyncWorker }
  let(:pending_scope) { :pending }
  let(:not_pending_scope) { :not_pending }
  let(:default_state) { :synced }
  let(:state_field) { :state }

  it_behaves_like 'a geo bulk registry update service'
end
