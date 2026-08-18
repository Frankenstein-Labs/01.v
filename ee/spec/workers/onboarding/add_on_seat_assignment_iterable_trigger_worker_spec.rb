# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::AddOnSeatAssignmentIterableTriggerWorker, :saas, type: :worker, feature_category: :onboarding do
  describe '#perform' do
    let(:worker_params) { { 'product_interaction' => '_product_interaction_' } }

    subject(:perform) { described_class.new.perform(namespace, user_ids, worker_params) }

    context 'when namespace does not exist' do
      let(:namespace) { nil }
      let(:user_ids) { [] }

      it 'does not run the iterable trigger worker' do
        expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

        perform
      end
    end

    context 'when namespace exists' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:user_1) { create(:user) }

      let(:user_ids) { [user_1.id] }
      let(:params) do
        {
          first_name: user_1.first_name,
          last_name: user_1.last_name,
          work_email: user_1.email,
          namespace_id: namespace.id,
          product_interaction: '_product_interaction_',
          existing_plan: namespace.actual_plan_name,
          opt_in: user_1.onboarding_status_email_opt_in,
          preferred_language: ::Gitlab::I18n.trimmed_language_name(user_1.preferred_language)
        }.stringify_keys
      end

      before do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_iterable)
                                                       .with(params)
                                                       .and_return({ success: true })
      end

      it 'calls the iterable trigger worker for each user', :sidekiq_inline do
        expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).with(params).and_call_original

        perform
      end

      context 'for multiple ids' do
        let_it_be(:user_2) { create(:user) }
        let(:user_ids) { [user_1.id, user_2.id] }

        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_iterable).and_return({ success: true })
        end

        it 'calls the iterable trigger worker for each user', :sidekiq_inline do
          expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).twice.and_call_original

          perform
        end
      end
    end
  end
end
