# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersion, type: :model, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to have_many(:occurrences) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_length_of(:version).is_at_most(255) }
  end

  describe '.by_component_id_and_version' do
    let_it_be(:matching_version) { create(:sbom_component_version) }
    let_it_be(:non_matching_version) { create(:sbom_component_version) }

    subject(:results) do
      described_class.by_component_id_and_version(matching_version.component_id, matching_version.version)
    end

    it 'returns only the matching version' do
      expect(results.to_a).to eq([matching_version])
    end
  end

  describe '.by_project' do
    let_it_be(:in_project_occurrence) { create(:sbom_occurrence) }
    let_it_be(:not_in_project_occurrence) { create(:sbom_occurrence) }

    subject { described_class.by_project(in_project_occurrence.project) }

    it { is_expected.to eq([in_project_occurrence.component_version]) }
  end

  describe '.by_component_id' do
    let_it_be(:matching_version) { create(:sbom_component_version) }
    let_it_be(:non_matching_version) { create(:sbom_component_version) }

    subject { described_class.by_component_id(matching_version.component_id) }

    it { is_expected.to eq([matching_version]) }
  end

  describe '.by_component_name' do
    let_it_be(:matching_occurrence) { create(:sbom_occurrence, component_name: 'activerecord') }

    before_all do
      create(:sbom_occurrence, component_name: 'activerecord-gitlab')
      create(:sbom_occurrence, component_name: 'ActiveRecord')
    end

    subject { described_class.by_component_name('activerecord') }

    it { is_expected.to eq([matching_occurrence.component_version]) }
  end

  describe '.order_by_version' do
    before_all do
      %w[1 2 3].each { |version| create(:sbom_component_version, version: version) }
    end

    subject { described_class.order_by_version(verse) }

    where(:verse) { %i[asc desc] }

    with_them do
      it 'orders by verse' do
        is_expected.to be_sorted(:version, verse)
      end
    end

    it 'sorts in ascending order by default' do
      expect(described_class.order_by_version).to be_sorted(:version, :asc)
    end
  end

  context 'with loose foreign key on sbom_component_versions.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:sbom_component_version, organization: parent) }
    end
  end
end
