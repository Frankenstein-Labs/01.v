# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::StartWorker, feature_category: :continuous_delivery do
  let_it_be(:rollout) { create(:cd_rollout) }

  describe '#perform' do
    it 'calls the kickoff service with the rollout' do
      expect_next_instance_of(::Cd::Rollouts::StartService, rollout) do |service|
        expect(service).to receive(:execute).and_return(ServiceResponse.success(payload: { rollout: rollout }))
      end

      described_class.new.perform(rollout.id)
    end

    context 'when the rollout does not exist' do
      it 'does nothing' do
        expect(::Cd::Rollouts::StartService).not_to receive(:new)

        expect { described_class.new.perform(non_existing_record_id) }.not_to raise_error
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { rollout.id }

      before do
        allow_next_instance_of(::Cd::Rollouts::StartService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { rollout: rollout }))
        end
      end
    end
  end
end
