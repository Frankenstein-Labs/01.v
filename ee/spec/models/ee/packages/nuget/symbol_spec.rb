# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Nuget::Symbol, feature_category: :package_registry do
  describe 'scopes' do
    describe '.project_id_in' do
      let_it_be(:project) { create(:project) }
      let_it_be(:other_project) { create(:project) }
      let_it_be(:nuget_symbol) { create(:nuget_symbol, project:) }
      let_it_be(:other_nuget_symbol) { create(:nuget_symbol, project: other_project) }

      subject { described_class.project_id_in([project.id]) }

      it { is_expected.to contain_exactly(nuget_symbol) }
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:packages_nuget_symbol_state)
          .class_name('Geo::PackagesNugetSymbolState')
          .inverse_of(:packages_nuget_symbol)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      before do
        stub_nuget_symbol_object_storage
      end

      let(:verifiable_model_record) { build(:nuget_symbol, object_storage_key: 'key') }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Nuget symbol for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_nuget_symbol_object_storage(enabled: false)
        create(:nuget_symbol, project: project_1)
      end

      # Nuget symbol for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_nuget_symbol_object_storage(enabled: true)
        create(:nuget_symbol, project: project_2)
      end

      # Nuget symbol for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_nuget_symbol_object_storage(enabled: true)
        create(:nuget_symbol, :object_storage, project: project_1)
      end

      # Nuget symbol for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_nuget_symbol_object_storage(enabled: false)
        create(:nuget_symbol, project: project_3)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
