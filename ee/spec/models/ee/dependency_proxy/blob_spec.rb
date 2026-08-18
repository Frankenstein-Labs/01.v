# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Blob, feature_category: :geo_replication do
  describe 'Geo replication' do
    before do
      stub_dependency_proxy_setting(enabled: true)
    end

    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:dependency_proxy_blob_state)
          .class_name('Geo::DependencyProxyBlobState')
          .inverse_of(:dependency_proxy_blob)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      before do
        stub_dependency_proxy_object_storage
      end

      let(:verifiable_model_record) { build(:dependency_proxy_blob) }
      let(:unverifiable_model_record) { build(:dependency_proxy_blob, :remote_store) }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Dependency Proxy Blob for the root group
      let!(:first_replicable_and_in_selective_sync) do
        stub_dependency_proxy_object_storage(enabled: false)
        create(:dependency_proxy_blob, group: group_1)
      end

      # Dependency Proxy Blob for a subgroup
      let!(:second_replicable_and_in_selective_sync) do
        stub_dependency_proxy_object_storage(enabled: false)
        create(:dependency_proxy_blob, group: nested_group_1)
      end

      # Dependency Proxy Blob for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        stub_dependency_proxy_object_storage(enabled: true)
        create(:dependency_proxy_blob, :remote_store, group: group_1)
      end

      # Dependency Proxy Blob for a group not in selective sync
      let!(:last_replicable_and_not_in_selective_sync) do
        stub_dependency_proxy_object_storage(enabled: false)
        create(:dependency_proxy_blob, group: group_2)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
