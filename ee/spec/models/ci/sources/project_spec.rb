# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Sources::Project, feature_category: :continuous_integration do
  describe 'Relations' do
    it { is_expected.to belong_to(:pipeline).required }
    it { is_expected.to belong_to(:source_project).required.class_name('::Project') }
  end

  describe 'Validations' do
    let!(:project_source) { create(:ci_sources_project) }

    it { is_expected.to validate_uniqueness_of(:pipeline_id).scoped_to(:source_project_id) }
  end

  context 'loose foreign key on ci_sources_projects.source_project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:project) }
      let!(:model) { create(:ci_sources_project, source_project: parent) }
    end
  end

  describe 'partitioning' do
    include Ci::PartitioningHelpers

    let(:pipeline) { create(:ci_pipeline) }
    let(:project_source) { create(:ci_sources_project, pipeline: pipeline) }

    before do
      stub_current_partition_id(ci_testing_partition_id)
    end

    it 'assigns the same partition id as the one that pipeline has' do
      expect(project_source.partition_id).to eq(ci_testing_partition_id)
    end
  end
end
