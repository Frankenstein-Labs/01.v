# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::DesignManagementActionUploadRegistry, :geo, feature_category: :geo_replication do
  let_it_be(:registry, freeze: true) { build(:geo_design_management_action_upload_registry) }

  specify 'factory is valid' do
    expect(registry).to be_valid
  end

  include_examples 'a Geo framework registry'
end
