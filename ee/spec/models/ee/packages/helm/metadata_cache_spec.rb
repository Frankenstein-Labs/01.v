# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Helm::MetadataCache, feature_category: :package_registry do
  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:packages_helm_metadata_cache_state)
          .class_name('Geo::PackagesHelmMetadataCacheState')
          .inverse_of(:packages_helm_metadata_cache)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      before do
        stub_helm_metadata_cache_object_storage
      end

      let(:verifiable_model_record) do
        build(:helm_metadata_cache, project: create(:project))
      end

      let(:unverifiable_model_record) do
        build(:helm_metadata_cache, :object_storage, project: create(:project))
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }

      # Helm metadata cache for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_helm_metadata_cache_object_storage(enabled: false)
        create(:helm_metadata_cache, project: project_1)
      end

      # Helm metadata cache for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_helm_metadata_cache_object_storage(enabled: false)
        create(:helm_metadata_cache, project: project_2)
      end

      # Helm metadata cache for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_helm_metadata_cache_object_storage(enabled: true)
        create(:helm_metadata_cache, :object_storage, project: project_1)
      end

      # Helm metadata cache for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_helm_metadata_cache_object_storage(enabled: false)
        create(:helm_metadata_cache, project: project_3)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
