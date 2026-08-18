# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::InviteSignupService, feature_category: :acquisition do
  let_it_be_with_reload(:user) do
    create(
      :user, onboarding_in_progress: true, onboarding_status_setup_for_company: true,
      onboarding_status_registration_type: 'invite'
    )
  end

  let(:params) { {} }
  let(:update_params) { { onboarding_status_role: 0 }.merge(params) }

  describe '#execute' do
    let(:updated_user) { execute[:user].reset }

    subject(:execute) { described_class.new(user, params: update_params).execute }

    context 'when updating onboarding_status_role' do
      let(:params) { { onboarding_status_role: 1 } }

      it 'updates the onboarding_status_role attribute' do
        expect(execute).to be_success
        expect(updated_user.onboarding_status_role_name).to eq('development_team_lead')
      end

      context 'when onboarding_status_role is missing' do
        let(:params) { { onboarding_status_role: nil } }

        it 'returns an error result' do
          expect(execute).to be_error
          expect(execute.message).to include("Onboarding status role can't be blank")
        end
      end
    end

    context 'when updating setup_for_company' do
      it 'updates the setup_for_company attribute' do
        expect(execute).to be_success
        expect(updated_user.onboarding_status_setup_for_company).to be(true)
      end
    end

    context 'when param contains an unsupported attribute' do
      let(:params) { { name: 'New Name' } }

      it 'does not update the attribute' do
        expect(execute).to be_success
        expect(updated_user.name).not_to eq('New Name')
      end
    end

    context 'with iterable concerns', :saas_onboarding, :saas_gitlab_com_subscriptions do
      let(:params) do
        {
          onboarding_status_registration_objective: 2,
          jobs_to_be_done_other: '_jobs_to_be_done_other_'
        }
      end

      let(:extra_iterable_params) { {} }
      let(:iterable_params) do
        {
          comment: '_jobs_to_be_done_other_',
          jtbd: 'code_storage',
          opt_in: user.onboarding_status_email_opt_in,
          preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
          product_interaction: 'Invited User',
          provider: 'gitlab',
          role: 'software_developer',
          setup_for_company: true,
          uid: user.id,
          work_email: user.email,
          existing_plan: 'ultimate'
        }.stringify_keys
      end

      before do
        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:generate_iterable).with(iterable_params).and_return({ success: true })
      end

      context 'when user has memberships' do
        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
        end

        it 'initiates iterable trigger creation', :sidekiq_inline do
          expect(::Onboarding::CreateIterableTriggerWorker)
            .to receive(:perform_async).with(iterable_params).and_call_original

          execute
        end
      end

      context 'when user has no memberships' do
        let(:iterable_params) { super().except('existing_plan') }

        it 'initiates iterable trigger creation', :sidekiq_inline do
          expect(::Onboarding::CreateIterableTriggerWorker)
            .to receive(:perform_async).with(iterable_params).and_call_original

          execute
        end
      end

      context 'when there are multiple members it picks the last one' do
        let(:iterable_params) { super().merge('existing_plan' => 'premium') }

        before do
          create(:group_with_plan, plan: :ultimate_plan, developers: user)
          create(:group_with_plan, plan: :premium_plan, developers: user)
        end

        it 'initiates iterable trigger creation', :sidekiq_inline do
          expect(::Onboarding::CreateIterableTriggerWorker)
            .to receive(:perform_async).with(iterable_params).and_call_original

          execute
        end
      end
    end

    context 'for onboarding redirect troubleshooting' do
      it 'writes onboarding_in_progress to cache', :use_clean_rails_memory_store_caching do
        expect do
          execute
        end.to change { Rails.cache.read("user_onboarding_in_progress:#{user.id}") }.from(nil).to(false)
      end
    end

    context 'with onboarding concerns', :saas_onboarding do
      it 'ends onboarding' do
        expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
      end
    end
  end
end
