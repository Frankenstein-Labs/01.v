# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesNugetSymbolReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:nuget_symbol) }

  include_examples 'a blob replicator'
end
