# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::UnstickLockedMergeRequestsService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let(:service) { described_class.new }

  describe '#execute' do
    context 'when MR has no merge_jid' do
      let(:merge_request) do
        create(
          :merge_request,
          :locked,
          source_project: project,
          state: :locked,
          merge_jid: nil
        )
      end

      context 'when MR is in a merge train' do
        before do
          create(:merge_train_car, merge_request: merge_request)
        end

        it 'does not do anything' do
          expect { service.execute }
            .not_to change { merge_request.reload.state }
            .from('locked')
        end
      end
    end
  end
end
