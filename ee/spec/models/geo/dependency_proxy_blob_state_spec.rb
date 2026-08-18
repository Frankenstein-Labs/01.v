# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::DependencyProxyBlobState, :geo, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:dependency_proxy_blob).inverse_of(:dependency_proxy_blob_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:dependency_proxy_blob) }
  end

  context 'with loose foreign key on dependency_proxy_blob_states.dependency_proxy_blob_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:dependency_proxy_blob) }
      let_it_be(:model, freeze: true) { create(:geo_dependency_proxy_blob_state, dependency_proxy_blob: parent) }
    end
  end

  context 'with loose foreign key on dependency_proxy_blob_states.group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:blob, freeze: true) { create(:dependency_proxy_blob) }
      let_it_be(:parent, freeze: true) { blob.group }
      let_it_be(:model, freeze: true) do
        create(:geo_dependency_proxy_blob_state, dependency_proxy_blob: blob, group: parent)
      end
    end
  end
end
