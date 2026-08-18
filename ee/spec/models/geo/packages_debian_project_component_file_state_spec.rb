# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PackagesDebianProjectComponentFileState, :geo, feature_category: :geo_replication do
  it { is_expected.to be_a ::Geo::VerificationStateDefinition }

  describe 'associations' do
    it 'belongs to packages_debian_project_component_file' do
      is_expected.to belong_to(:packages_debian_project_component_file)
        .class_name('::Packages::Debian::ProjectComponentFile')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:packages_debian_project_component_file) }
    it { is_expected.to validate_presence_of(:verification_state) }
  end

  describe '#copy_project_id' do
    let_it_be(:component_file) { create(:debian_project_component_file) }

    it 'copies project_id from the component file distribution on create' do
      state = described_class.new(packages_debian_project_component_file: component_file)
      state.verification_state = 0

      state.validate

      expect(state.project_id).to eq(component_file.component.distribution.project_id)
    end
  end
end
