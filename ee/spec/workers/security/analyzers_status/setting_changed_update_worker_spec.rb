# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::SettingChangedUpdateWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  it 'has the correct concurrency limit' do
    expect(described_class.get_concurrency_limit).to eq(50)
  end

  describe '#perform' do
    let(:project_ids) { [1, 2, 3] }
    let(:analyzer_type) { 'secret_detection' }

    before do
      allow(Security::AnalyzersStatus::SettingsBasedUpdateService).to receive(:execute)
      allow(Security::AnalyzersStatus::ProfileBasedUpdateService).to receive(:execute)
    end

    shared_examples 'calls neither service' do
      it 'does not call SettingsBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
      end

      it 'does not call ProfileBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::ProfileBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when analyzer_type routes to ProfileBasedUpdateService' do
      Security::AnalyzersStatus::BaseUpdateService::PROFILE_UPDATE_TYPES.map(&:to_s).each do |profile_type|
        context "when analyzer_type is '#{profile_type}'" do
          let(:analyzer_type) { profile_type }

          it 'calls ProfileBasedUpdateService with the given arguments' do
            worker.perform(project_ids, analyzer_type)
            expect(Security::AnalyzersStatus::ProfileBasedUpdateService)
              .to have_received(:execute).with(project_ids, analyzer_type)
          end

          it 'does not call SettingsBasedUpdateService' do
            worker.perform(project_ids, analyzer_type)
            expect(Security::AnalyzersStatus::SettingsBasedUpdateService).not_to have_received(:execute)
          end
        end
      end
    end

    context "when analyzer_type is 'secret_detection'" do
      it 'calls SettingsBasedUpdateService with the given arguments' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::SettingsBasedUpdateService)
          .to have_received(:execute).with(project_ids, analyzer_type)
      end

      it 'does not call ProfileBasedUpdateService' do
        worker.perform(project_ids, analyzer_type)
        expect(Security::AnalyzersStatus::ProfileBasedUpdateService).not_to have_received(:execute)
      end
    end

    context 'when project_ids is empty' do
      let(:project_ids) { [] }

      include_examples 'calls neither service'
    end

    context 'when project_ids is nil' do
      let(:project_ids) { nil }

      include_examples 'calls neither service'
    end

    context 'when analyzer_type is empty' do
      let(:analyzer_type) { '' }

      include_examples 'calls neither service'
    end

    context 'when analyzer_type is nil' do
      let(:analyzer_type) { nil }

      include_examples 'calls neither service'
    end

    context 'when both project_ids and analyzer_type are not present' do
      let(:project_ids) { [] }
      let(:analyzer_type) { nil }

      include_examples 'calls neither service'
    end
  end
end
