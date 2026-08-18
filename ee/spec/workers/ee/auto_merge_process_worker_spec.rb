# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMergeProcessWorker, feature_category: :continuous_delivery do
  describe '#perform' do
    subject(:perform) { described_class.new.perform(args) }

    context 'when a project id is passed' do
      let_it_be(:project) { create(:project) }
      let(:merge_request) { create(:merge_request, :unique_branches) }
      let(:project_id) { project.id }
      let(:merge_service) { instance_double(AutoMergeService, process: true) }
      let!(:mwcp_merge_request_1) do
        create(:merge_request, :unique_branches, :with_head_pipeline, :merge_when_checks_pass, target_project: project,
          source_project: project)
      end

      let!(:mwcp_merge_request_2) do
        create(:merge_request, :unique_branches, :with_head_pipeline, :merge_when_checks_pass, target_project: project,
          source_project: project)
      end

      let!(:normal_merge_request_2) do
        create(:merge_request, :unique_branches, :with_head_pipeline, target_project: project, source_project: project)
      end

      let(:args) do
        {
          'project_id' => project_id,
          'merge_request_id' => merge_request.id
        }
      end

      before do
        stub_licensed_features(merge_request_title_regex_check: true)
      end

      it 'executes the auto merge service for only auto merge MRs' do
        expect(AutoMergeService).to receive(:new).exactly(3).times.and_return(merge_service)

        expect(merge_service).to receive(:process).with(merge_request)
        expect(merge_service).to receive(:process).with(mwcp_merge_request_1)
        expect(merge_service).to receive(:process).with(mwcp_merge_request_2)

        perform
      end

      context 'when the project id is not valid' do
        let(:project_id) { -1 }

        it 'executes the auto merge service for only the merge request' do
          expect(AutoMergeService).to receive(:new).once.and_return(merge_service)

          expect(merge_service).to receive(:process).with(merge_request)

          perform
        end
      end

      context 'when the merge_request_title_regex_check license is not available' do
        before do
          stub_licensed_features(merge_request_title_regex_check: false)
        end

        it 'executes the auto merge service for only the merge request' do
          expect(AutoMergeService).to receive(:new).once.and_return(merge_service)

          expect(merge_service).to receive(:process).with(merge_request)

          perform
        end
      end

      context 'when there are more merge requests than the limit' do
        let(:args) do
          {
            'project_id' => project_id
          }
        end

        before do
          stub_const("AutoMergeProcessWorker::PROJECT_MR_LIMIT", 1)
        end

        it 'executes the auto merge service for limited auto merge MRs' do
          expect(AutoMergeService).to receive(:new).once.and_return(merge_service)

          expect(merge_service).to receive(:process).with(mwcp_merge_request_1)

          perform
        end
      end
    end
  end
end
