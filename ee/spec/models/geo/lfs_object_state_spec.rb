# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::LfsObjectState, :geo, type: :model, feature_category: :geo_replication do
  context 'with loose foreign key on lfs_object_states.lfs_object_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:lfs_object) }
      let_it_be(:model, freeze: true) { create(:geo_lfs_object_state, lfs_object: parent) }
    end
  end
end
