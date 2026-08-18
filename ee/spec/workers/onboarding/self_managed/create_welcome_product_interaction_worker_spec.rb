# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SelfManaged::CreateWelcomeProductInteractionWorker, feature_category: :onboarding do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    let_it_be(:user) { create(:user) }

    subject(:perform) { described_class.new.perform(user.id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [user.id] }

      before do
        allow_next_instance_of(Onboarding::SelfManaged::CreateWelcomeProductInteractionService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end
    end

    context 'when the user exists' do
      it 'calls the service' do
        expect_next_instance_of(
          Onboarding::SelfManaged::CreateWelcomeProductInteractionService, user: user
        ) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        perform
      end
    end

    context 'when the user does not exist' do
      subject(:perform) { described_class.new.perform(non_existing_record_id) }

      it 'does not call the service' do
        expect(Onboarding::SelfManaged::CreateWelcomeProductInteractionService).not_to receive(:new)

        perform
      end
    end

    context 'when the service returns an error' do
      before do
        allow_next_instance_of(Onboarding::SelfManaged::CreateWelcomeProductInteractionService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'Submission failed'))
        end
      end

      it 'logs the error' do
        allow(Sidekiq.logger).to receive(:error)

        perform

        expect(Sidekiq.logger).to have_received(:error).with(
          hash_including('message' => 'Submission failed', 'user_id' => user.id)
        )
      end
    end

    context 'when the service returns an error with an array message' do
      before do
        allow_next_instance_of(Onboarding::SelfManaged::CreateWelcomeProductInteractionService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.error(message: ['email is invalid', 'country missing']))
        end
      end

      it 'coerces the message to a string for structured logging' do
        allow(Sidekiq.logger).to receive(:error)

        perform

        expect(Sidekiq.logger).to have_received(:error).with(
          hash_including('message' => '["email is invalid", "country missing"]', 'user_id' => user.id)
        )
      end
    end
  end
end
