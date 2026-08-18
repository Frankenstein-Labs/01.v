# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::ApplyTrialService, :saas, :use_clean_rails_memory_store_caching, feature_category: :acquisition do
  let_it_be(:namespace) { create(:group_with_plan) }
  let_it_be(:user) { create(:user, owner_of: namespace) }

  let(:trial_user_information) { { namespace_id: namespace.id } }
  let(:apply_trial_params) do
    {
      uid: user.id,
      trial_user_information: trial_user_information
    }
  end

  before do
    Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", GitlabSubscriptions::Trials::TRIAL_TYPES)
  end

  describe '.execute' do
    before do
      allow_trial_creation(namespace, trial_user_information)
    end

    subject(:execute) { described_class.execute(**apply_trial_params) }

    context 'when trial is applied successfully' do
      it 'returns success: true' do
        expect(execute).to be_success
      end

      it_behaves_like 'records an onboarding progress action', :trial_started
    end
  end

  describe '#execute' do
    subject(:execute) { described_class.new(**apply_trial_params).execute }

    context 'when trial is applied successfully' do
      let(:trial_user_information) do
        {
          namespace_id: namespace.id,
          add_on_name: 'duo_enterprise'
        }
      end

      context 'when namespace has a free plan' do
        it 'uses FREE_TRIAL_TYPE_V2 for free plan namespaces' do
          allow_trial_creation(
            namespace,
            trial_user_information.merge(trial_type: GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2)
          )

          expect(execute).to be_success
        end

        it 'clears the dap access cache for the user' do
          allow_trial_creation(
            namespace,
            trial_user_information.merge(trial_type: GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2)
          )

          expect(User).to receive(:clear_group_with_ai_available_cache).with(user.id)

          expect(execute).to be_success
        end
      end

      context 'when namespace has a premium plan' do
        let_it_be(:namespace) { create(:group_with_plan, plan: :premium_plan) }

        it 'uses PREMIUM_TRIAL_TYPE_V2 for premium plan namespaces' do
          allow_trial_creation(
            namespace,
            trial_user_information.merge(trial_type: GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2)
          )

          expect(execute).to be_success
        end
      end
    end

    context 'when valid to generate a trial' do
      context 'when trial is applied successfully' do
        before do
          allow_trial_creation(namespace, trial_user_information)
        end

        it 'returns success: true' do
          allow(Namespace.sticking).to receive(:find_caught_up_replica).and_call_original
          expect(Namespace.sticking).to receive(:find_caught_up_replica).with(:namespace, namespace.id)

          expect(execute).to be_success
        end

        it_behaves_like 'records an onboarding progress action', :trial_started

        it 'does not auto-assign a duo seat' do
          expect { execute }.not_to change { user.assigned_add_ons.count }
        end

        context 'when namespace has already had a trial' do
          let_it_be(:namespace) do
            create(
              :group_with_plan,
              plan: :free_plan,
              trial: true,
              trial_starts_on: 2.years.ago,
              trial_ends_on: 1.year.ago
            )
          end

          it { is_expected.to be_success }
        end
      end

      context 'with error while applying the trial' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:generate_trial)
            .and_return(success: false, data: { errors: ['some error'] })
        end

        it 'returns success: false with errors and reason' do
          expect(execute).to be_error.and have_attributes(
            message: ['some error'], reason: described_class::GENERIC_TRIAL_ERROR
          )
        end

        it_behaves_like 'does not record an onboarding progress action'
      end
    end

    context 'when not valid to generate a trial' do
      context 'when namespace_id is not in the trial_user_information' do
        let(:trial_user_information) { {} }

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end

      context 'when namespace does not exist' do
        let(:trial_user_information) { { namespace_id: non_existing_record_id } }

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end

      context 'when namespace is already on a trial' do
        let_it_be(:namespace) do
          create(
            :group_with_plan,
            plan: :ultimate_trial_plan,
            trial: true,
            trial_starts_on: 2.years.ago,
            trial_ends_on: 1.year.ago
          )
        end

        it 'returns success: false with errors' do
          expect(execute).to be_error.and have_attributes(message: /Not valid to generate a trial/)
        end
      end
    end
  end

  describe '#valid_to_generate_trial?' do
    subject(:valid_to_generate_trial) { described_class.new(**apply_trial_params).valid_to_generate_trial? }

    context 'when it is valid to generate a trial' do
      it { is_expected.to be true }
    end

    context 'when namespace_id is not in the trial_user_information' do
      let(:trial_user_information) { {} }

      it { is_expected.to be false }
    end

    context 'when namespace does not exist' do
      let(:trial_user_information) { { namespace_id: non_existing_record_id } }

      it { is_expected.to be false }
    end

    context 'when ineligible' do
      before do
        Rails.cache.write("namespaces:eligible_trials:#{namespace.id}", ['gitlab_duo_pro'])
      end

      it { is_expected.to be false }
    end

    context 'with valid plans' do
      where(plan: ::Plan::PLANS_ELIGIBLE_FOR_TRIAL)

      with_them do
        let(:namespace) { create(:group_with_plan, plan: "#{plan}_plan") }

        it { is_expected.to be true }
      end
    end

    context 'with an invalid plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it { is_expected.to be false }
    end
  end

  def allow_trial_creation(_namespace, trial_user)
    allow(Gitlab::SubscriptionPortal::Client)
      .to receive(:generate_trial).with(uid: user.id, trial_user: trial_user).and_return(success: true)
  end
end
