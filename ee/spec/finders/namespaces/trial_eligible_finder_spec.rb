# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::TrialEligibleFinder, feature_category: :subscription_management do
  describe '#execute', :saas, :use_clean_rails_memory_store_caching do
    let_it_be(:user) { create(:user) }
    let_it_be(:free_namespace) { create(:group, name: 'Zeta', owners: user) }
    let_it_be(:premium_namespace) { create(:group_with_plan, name: 'Alpha', plan: :premium_plan, owners: user) }

    subject(:execute) { described_class.new(params).execute }

    shared_examples 'cached eligible namespaces' do
      let(:cache_key_free_namespace) { "namespaces:eligible_trials:#{free_namespace.id}" }
      let(:cache_key_premium_namespace) { "namespaces:eligible_trials:#{premium_namespace.id}" }

      let(:namespaces_response) do
        {
          free_namespace.id.to_s => GitlabSubscriptions::Trials::TRIAL_TYPES,
          premium_namespace.id.to_s => [GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2, 'gitlab_duo_pro']
        }
      end

      let(:cache_write) do
        {
          cache_key_free_namespace => namespaces_response[free_namespace.id.to_s],
          cache_key_premium_namespace => namespaces_response[premium_namespace.id.to_s]
        }
      end

      before do
        allow(Rails.cache).to receive(:exist?).with(cache_key_free_namespace).once.and_call_original
      end

      context 'when cache exists for all namespaces' do
        before do
          Rails.cache.write_multi(cache_write)
          allow(Rails.cache).to receive(:exist?).with(cache_key_premium_namespace).once.and_call_original
        end

        it { is_expected.to eq([premium_namespace, free_namespace]) }

        context 'when requested trial is not eligible' do
          let(:namespaces_response) do
            {
              free_namespace.id.to_s => ['gitlab_duo_pro'],
              premium_namespace.id.to_s => [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2]
            }
          end

          it { is_expected.to be_empty }
        end

        context 'when first namespace has the ultimate plan' do
          let(:cache_write) { { cache_key_premium_namespace => namespaces_response[premium_namespace.id.to_s] } }

          before do
            create(:gitlab_subscription, :ultimate, namespace: free_namespace)
          end

          it { is_expected.to eq([premium_namespace]) }
        end
      end

      context 'when cache is not complete' do
        before do
          Rails.cache.write(cache_key_free_namespace, namespaces_response[free_namespace.id.to_s])

          allow(Rails.cache).to receive(:exist?).with(cache_key_premium_namespace).once.and_call_original
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:namespace_eligible_trials)
                  .with(namespace_ids: containing_exactly(free_namespace.id, premium_namespace.id))
                  .and_return(response)
        end

        context 'with a successful CustomersDot query', :aggregate_failures do
          let(:response) { { success: true, data: { namespaces: namespaces_response } } }

          it 'caches the query response' do
            expect(Rails.cache).to receive(:write_multi).with(
              {
                cache_key_free_namespace => namespaces_response[free_namespace.id.to_s],
                cache_key_premium_namespace => namespaces_response[premium_namespace.id.to_s]
              },
              expires_in: 8.hours
            ).and_call_original

            expect(execute).to eq([premium_namespace, free_namespace])
          end
        end

        context 'with an unsuccessful CustomersDot query' do
          let(:response) { { success: false } }

          it { is_expected.to be_empty }

          it 'does not cache the query response' do
            expect(Rails.cache).not_to receive(:write_multi)

            execute
          end
        end
      end
    end

    context 'with user and namespace' do
      let(:params) { { user: build(:user), namespace: build(:group) } }

      it 'raises an error' do
        expect { execute }.to raise_error(ArgumentError, 'Only User or Namespace can be provided, not both')
      end
    end

    context 'with user' do
      let(:params) { { user: user } }

      it_behaves_like 'cached eligible namespaces'

      context 'when a user does not own any groups' do
        let(:params) { super().merge(user: build(:user)) }

        it { is_expected.to eq([]) }
      end
    end

    context 'with namespaces' do
      let(:params) { { namespace: [free_namespace, premium_namespace] } }

      it_behaves_like 'cached eligible namespaces'
    end
  end
end
