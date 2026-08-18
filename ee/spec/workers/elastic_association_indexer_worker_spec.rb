# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticAssociationIndexerWorker, feature_category: :global_search do
  subject(:worker) { described_class.new }

  let(:indexed_associations) { [:issues] }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  context 'when elasticsearch_indexing is disabled' do
    it 'does nothing' do
      stub_ee_application_setting(elasticsearch_indexing: false)
      expect(Elastic::ProcessBookkeepingService).not_to receive(:maintain_indexed_associations)

      worker.perform(Project.name, 1, indexed_associations)
    end
  end

  context 'when elasticsearch_indexing is enabled' do
    let_it_be(:project) { create(:project) }

    let(:job_args) { [project.class.name, project_id, indexed_associations] }
    let(:project_id) { project.id }

    it_behaves_like 'an idempotent worker' do
      context 'when object is not setup to use elasticsearch' do
        it 'does nothing' do
          expect_next_found_instance_of(Project) do |p|
            expect(p).to receive(:use_elasticsearch?).and_return(false)
          end
          expect(Elastic::ProcessBookkeepingService).not_to receive(:maintain_indexed_associations)

          worker.perform(*job_args)
        end
      end

      it 'updates associations for the object' do
        expect(Elastic::ProcessBookkeepingService)
          .to receive(:maintain_indexed_associations).with(project, indexed_associations)

        worker.perform(*job_args)
      end

      context 'when record is not found' do
        let(:project_id) { non_existing_record_id }

        it 'does nothing' do
          expect(Elastic::ProcessBookkeepingService).not_to receive(:maintain_indexed_associations)

          worker.perform(*job_args)
        end
      end
    end
  end
end
