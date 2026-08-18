# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ScheduleInstanceSettingChangedUpdateWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { ['secret_detection'] }
  end

  describe '#perform' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }

    context 'when analyzer_type is present' do
      it 'enqueues ScheduleSettingChangedUpdateWorker with a delay for each batch of projects' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
          .to receive(:perform_in).at_least(:once)

        worker.perform('secret_detection')
      end
    end

    context 'when analyzer_type is nil' do
      it 'does not enqueue any workers' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
          .not_to receive(:perform_in)

        worker.perform(nil)
      end
    end

    context 'when analyzer_type is blank' do
      it 'does not enqueue any workers' do
        expect(Security::AnalyzersStatus::ScheduleSettingChangedUpdateWorker)
          .not_to receive(:perform_in)

        worker.perform('')
      end
    end
  end
end
