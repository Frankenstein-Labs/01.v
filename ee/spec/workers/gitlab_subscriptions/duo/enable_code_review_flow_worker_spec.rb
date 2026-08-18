# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Duo::EnableCodeReviewFlowWorker, feature_category: :duo_code_review do
  let_it_be(:namespace) { create(:group) }

  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [namespace.id] }

    before do
      allow_next_instance_of(GitlabSubscriptions::Duo::EnableCodeReviewFlowService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end
    end
  end

  describe '#perform' do
    context 'when the namespace exists' do
      it 'calls EnableCodeReviewFlowService#execute with the namespace' do
        expect_next_instance_of(
          GitlabSubscriptions::Duo::EnableCodeReviewFlowService,
          namespace: namespace
        ) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(namespace.id)
      end
    end

    context 'when the namespace does not exist' do
      it 'does not call EnableCodeReviewFlowService' do
        expect(GitlabSubscriptions::Duo::EnableCodeReviewFlowService).not_to receive(:new)

        worker.perform(non_existing_record_id)
      end
    end
  end
end
