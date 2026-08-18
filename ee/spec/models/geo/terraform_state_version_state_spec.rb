# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::TerraformStateVersionState, :geo, type: :model, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:terraform_state_version).inverse_of(:terraform_state_version_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:terraform_state_version) }
  end

  context 'with loose foreign key on terraform_state_version_state.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:project) }
      let_it_be(:model, freeze: true) { create(:geo_terraform_state_version_state, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on terraform_state_version_state.terraform_state_version_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:terraform_state_version) }
      let_it_be(:model, freeze: true) do
        create(:geo_terraform_state_version_state, terraform_state_version_id: parent.id)
      end
    end
  end
end
