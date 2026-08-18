# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesDebianProjectComponentFileReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:debian_project_component_file) }

  include_examples 'a blob replicator'
end
