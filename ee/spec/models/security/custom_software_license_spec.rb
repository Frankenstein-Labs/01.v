# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CustomSoftwareLicense, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject(:custom_software_license) { build(:custom_software_license) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to(validate_uniqueness_of(:name).scoped_to(%i[project_id])) }
  end

  describe 'scopes' do
    let_it_be(:custom_license) { create(:custom_software_license, name: 'CustomLicense') }
    let_it_be(:other_custom_license) { create(:custom_software_license, name: 'OtherCustomLicense') }

    describe '.by_name' do
      it { expect(described_class.by_name(custom_license.name)).to contain_exactly(custom_license) }
    end

    describe '.by_project' do
      it { expect(described_class.by_project(custom_license.project)).to contain_exactly(custom_license) }
    end
  end

  describe '#canonical_id' do
    let_it_be(:name) { 'CustomLicense' }
    let_it_be(:custom_license) { create(:custom_software_license, name: name) }

    subject { custom_license.canonical_id }

    it 'returns the name in a downcased string' do
      is_expected.to eq(name.downcase)
    end
  end
end
