# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::GraphPath, type: :model, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:path_length) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:ancestor).required }
    it { is_expected.to belong_to(:descendant).required }
    it { is_expected.to belong_to(:project) }
  end

  context 'with loose foreign key on sbom_graph_paths.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:sbom_graph_path, project: parent) }
    end
  end
end
