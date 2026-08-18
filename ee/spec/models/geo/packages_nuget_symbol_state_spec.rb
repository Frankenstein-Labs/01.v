# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesNugetSymbolState, :geo, feature_category: :geo_replication do
  it { is_expected.to be_a ::Geo::VerificationStateDefinition }

  describe 'associations' do
    it { is_expected.to belong_to(:packages_nuget_symbol).class_name('::Packages::Nuget::Symbol') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:packages_nuget_symbol) }
    it { is_expected.to validate_presence_of(:verification_state) }
  end
end
