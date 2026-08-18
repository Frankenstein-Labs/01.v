# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackageFileState, :geo, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:package_file).inverse_of(:package_file_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:package_file) }
  end
end
