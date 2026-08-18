# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateArchivedAnalyzerStatusWorker, feature_category: :security_asset_inventories do
  let(:project_id) { non_existing_record_id }

  subject(:run_worker) { described_class.new.perform(project_id) }

  describe '#perform' do
    before do
      allow(Security::AnalyzersStatus::UpdateArchivedService).to receive(:execute)
    end

    it 'calls the UpdateArchivedService' do
      run_worker

      expect(Security::AnalyzersStatus::UpdateArchivedService)
        .to have_received(:execute).with(Project.find_by_id(project_id))
    end
  end

  include_examples 'an idempotent worker' do
    let_it_be(:project) { create(:project) }

    let(:job_args) { project.id }
  end
end
