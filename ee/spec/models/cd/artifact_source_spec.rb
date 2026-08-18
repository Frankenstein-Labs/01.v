# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ArtifactSource, feature_category: :continuous_delivery do
  let_it_be(:service) { create(:cd_service) }

  describe 'factory' do
    it 'creates a valid artifact source using factory defaults' do
      expect(create(:cd_artifact_source)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:service).required }
    it { is_expected.to have_many(:versions) }
  end

  describe 'validations' do
    subject { build(:cd_artifact_source, service: service) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:source_ref) }
    it { is_expected.to validate_length_of(:source_ref).is_at_most(255) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    it 'allows multiple artifact sources for the same service' do
      create(:cd_artifact_source, service: service)

      expect(build(:cd_artifact_source, service: service)).to be_valid
    end

    it 'allows multiple artifact sources with the same name for the same service' do
      create(:cd_artifact_source, service: service, name: 'api')

      expect(build(:cd_artifact_source, service: service, name: 'api')).to be_valid
    end
  end

  describe 'sharding key' do
    subject { build(:cd_artifact_source, service: service) }

    it { is_expected.to populate_sharding_key(:organization_id).with(service.organization_id) }
  end

  describe '.for_source_ref' do
    let_it_be(:matching) { create(:cd_artifact_source, source_ref: 'registry.example.com/group/project/web') }
    let_it_be(:other) { create(:cd_artifact_source, source_ref: 'registry.example.com/group/project/api') }

    it 'returns only sources with the given source_ref' do
      expect(described_class.for_source_ref('registry.example.com/group/project/web')).to contain_exactly(matching)
    end
  end
end
