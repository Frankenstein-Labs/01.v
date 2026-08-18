# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectState, :geo, type: :model, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:project).inverse_of(:project_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:project) }
  end

  context 'with loose foreign key on project_states.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:project) }
      let_it_be(:model, freeze: true) { create(:geo_project_state, project: parent) }
    end
  end
end
