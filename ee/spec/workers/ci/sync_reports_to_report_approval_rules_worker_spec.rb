# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::SyncReportsToReportApprovalRulesWorker, feature_category: :source_code_management do
  it 'is labeled as low urgency' do
    expect(described_class.get_urgency).to eq(:low)
  end

  describe '#perform' do
    let(:pipeline) { double(:pipeline, id: 42, project: project) }
    let(:sync_service) { double(:service, execute: true) }
    let_it_be(:project) { create(:project) }

    context 'when pipeline exists' do
      before do
        allow(Ci::Pipeline).to receive(:find_by_id).with(pipeline.id) { pipeline }
      end

      it "executes SyncReportsToApprovalRulesService for given pipeline" do
        expect(Ci::SyncReportsToApprovalRulesService).to receive(:new)
          .with(pipeline).once.and_return(sync_service)

        described_class.new.perform(pipeline.id)
      end

      it "enqueues UpdateApprovalRulesForRelatedMrsWorker" do
        expect(Ci::SyncReportsToApprovalRulesService).to receive(:new)
          .with(pipeline).once.and_return(sync_service)

        expect(Ci::UpdateApprovalRulesForRelatedMrsWorker).to receive(:perform_async).with(pipeline.id)

        described_class.new.perform(pipeline.id)
      end
    end

    context 'when pipeline is missing' do
      it 'does not execute SyncReportsToApprovalRulesService' do
        expect(Ci::SyncReportsToApprovalRulesService).not_to receive(:new)

        described_class.new.perform(pipeline.id)
      end
    end
  end
end
