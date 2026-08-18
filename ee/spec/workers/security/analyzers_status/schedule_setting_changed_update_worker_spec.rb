# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }
  let(:analyzer_type) { 'secret_detection' }
  let(:update_worker) { Security::AnalyzersStatus::SettingChangedUpdateWorker }

  before do
    allow(update_worker).to receive(:perform_in)
  end

  describe '#perform' do
    context 'when project_ids is empty' do
      let(:project_ids) { [] }

      it 'doesnt schedule any SettingChangedUpdateWorker jobs' do
        worker.perform(project_ids, analyzer_type)
        expect(update_worker).not_to have_received(:perform_in)
      end
    end

    context 'when project_ids is nil' do
      let(:project_ids) { nil }

      it 'doesnt schedule any SettingChangedUpdateWorker jobs' do
        worker.perform(project_ids, analyzer_type)
        expect(update_worker).not_to have_received(:perform_in)
      end
    end

    context 'when analyzer_type is empty' do
      let(:project_ids) { [1, 2, 3] }
      let(:analyzer_type) { '' }

      it 'doesnt schedule any SettingChangedUpdateWorker jobs' do
        worker.perform(project_ids, analyzer_type)
        expect(update_worker).not_to have_received(:perform_in)
      end
    end

    context 'when analyzer_type is nil' do
      let(:project_ids) { [1, 2, 3] }
      let(:analyzer_type) { nil }

      it 'doesnt schedule any SettingChangedUpdateWorker jobs' do
        worker.perform(project_ids, analyzer_type)
        expect(update_worker).not_to have_received(:perform_in)
      end
    end

    context 'when project_ids count is greater than batch size' do
      let(:project_ids) { [1, 2, 3, 4, 5] }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'schedules multiple SettingChangedUpdateWorker jobs with correct batches and delays' do
        worker.perform(project_ids, analyzer_type)

        expect(update_worker).to have_received(:perform_in).exactly(3).times
        expect(update_worker).to have_received(:perform_in).with(described_class::DELAY * 0, [1, 2], analyzer_type)
        expect(update_worker).to have_received(:perform_in).with(described_class::DELAY * 1, [3, 4], analyzer_type)
        expect(update_worker).to have_received(:perform_in).with(described_class::DELAY * 2, [5], analyzer_type)
      end
    end
  end
end
