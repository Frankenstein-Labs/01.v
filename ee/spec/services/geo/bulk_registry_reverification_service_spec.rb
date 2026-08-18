# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BulkRegistryReverificationService, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:model_name) { 'Geo::MergeRequestDiffRegistry' }
  let(:registry_states) { registry_class::VERIFICATION_STATE_VALUES }
  let(:worker) { Geo::BulkRegistryReverificationWorker }
  let(:pending_scope) { :verification_pending }
  let(:not_pending_scope) { :verification_not_pending }
  let(:default_state) { :verification_succeeded }
  let(:state_field) { :verification_state }

  it_behaves_like 'a geo bulk registry update service'
end
