# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticsearchIndexedProject, feature_category: :global_search do
  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  let_it_be(:project) { create(:project) }

  let(:container) { :elasticsearch_indexed_project }
  let(:container_attributes) { { project: project } }

  let(:required_attribute) { :project_id }

  let(:index_action) do
    expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(project)
  end

  let(:delete_action) do
    expect(ElasticDeleteProjectWorker).to receive(:perform_async)
      .with(project.id, project.es_id, 'delete_project' => false)
  end

  it_behaves_like 'an elasticsearch indexed container' do
    context 'when elasticsearch_indexing is false' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      describe 'callbacks' do
        describe 'on save' do
          subject(:elasticsearch_indexed_project) { build(container, container_attributes) }

          it 'triggers index but does not index the data' do
            is_expected.to receive(:index)
            expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

            elasticsearch_indexed_project.save!
          end
        end

        describe 'on destroy' do
          subject(:elasticsearch_indexed_project) { create(container, container_attributes) }

          it 'triggers delete_from_index but does not delete data from index' do
            is_expected.to receive(:delete_from_index)
            expect(ElasticDeleteProjectWorker).not_to receive(:perform_async)

            elasticsearch_indexed_project.destroy!
          end
        end
      end
    end
  end
end
