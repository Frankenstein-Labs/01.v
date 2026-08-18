# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CartAbandonmentWorker, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }

  let(:product_interaction) { 'cart abandonment - SaaS Premium' }
  let(:previous_plan_name) { 'free' }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when user does not exist' do
      it 'returns early without calling service' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(non_existing_record_id, namespace.id, product_interaction, previous_plan_name)
      end
    end

    context 'when namespace does not exist' do
      it 'returns early without calling service' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(user.id, non_existing_record_id, product_interaction, previous_plan_name)
      end
    end

    context 'when user purchased a paid plan' do
      before do
        allow(Namespace).to receive(:find_by_id).with(namespace.id).and_return(namespace)
        allow(namespace).to receive(:actual_plan_name).and_return('premium')
      end

      it 'does not send lead' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
      end
    end

    context 'when namespace actual_plan_name returns nil' do
      let(:plans_data) do
        [
          Hashie::Mash.new(id: 'premium-plan-id', code: 'premium'),
          Hashie::Mash.new(id: 'ultimate-plan-id', code: 'ultimate')
        ]
      end

      before do
        allow(Namespace).to receive(:find_by_id).with(namespace.id).and_return(namespace)
        allow(namespace).to receive(:actual_plan_name).and_return(nil)
        allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
          allow(service).to receive(:execute).and_return(plans_data)
        end
      end

      it 'sends lead because plan name is nil' do
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
      end
    end

    context 'when plan has not changed' do
      let(:previous_plan_name) { 'free' }
      let(:plans_data) do
        [
          Hashie::Mash.new(id: 'premium-plan-id', code: 'premium'),
          Hashie::Mash.new(id: 'ultimate-plan-id', code: 'ultimate')
        ]
      end

      before do
        allow(Namespace).to receive(:find_by_id).with(namespace.id).and_return(namespace)
        allow(namespace).to receive(:actual_plan_name).and_return('free')
        allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
          allow(service).to receive(:execute).and_return(plans_data)
        end
      end

      it 'sends lead because user never upgraded' do
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
      end
    end

    context 'when user did not purchase' do
      let(:plans_data) do
        [
          Hashie::Mash.new(id: 'premium-plan-id', code: 'premium'),
          Hashie::Mash.new(id: 'ultimate-plan-id', code: 'ultimate')
        ]
      end

      before do
        allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
          allow(service).to receive(:execute).and_return(plans_data)
        end
      end

      it 'sends lead with correct params' do
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expect(service).to receive(:execute).with(
            hash_including(
              product_interaction: product_interaction,
              work_email: user.email,
              opt_in: user.onboarding_status_email_opt_in,
              namespace_id: namespace.id,
              plan_id: 'premium-plan-id',
              existing_plan: namespace.actual_plan_name,
              skip_country_validation: true
            )
          )
        end

        worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
      end

      context 'with optional user attributes' do
        let_it_be(:user_with_attrs) { create(:user) }

        let(:role_name) { 'software_developer' }
        let(:preferred_language) { 'zh_CN' }
        let(:trimmed_language_name) { 'Chinese, Simplified' }

        before do
          allow(User).to receive(:find_by_id).with(user_with_attrs.id).and_wrap_original do |method, *args|
            method.call(*args).tap do |found_user|
              allow(found_user).to receive_messages(
                onboarding_status_role_name: role_name,
                preferred_language: preferred_language
              )
            end
          end
          allow(::Gitlab::I18n).to receive(:trimmed_language_name)
            .with(preferred_language).and_return(trimmed_language_name)
        end

        it 'includes role and preferred_language when present' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_including(
                role: role_name,
                preferred_language: trimmed_language_name
              )
            )
          end

          worker.perform(user_with_attrs.id, namespace.id, product_interaction, previous_plan_name)
        end
      end

      context 'without optional user attributes' do
        let_it_be(:user_without_attrs) { create(:user) }

        before do
          allow(User).to receive(:find_by_id).with(user_without_attrs.id).and_wrap_original do |method, *args|
            method.call(*args).tap do |found_user|
              allow(found_user).to receive_messages(
                onboarding_status_role_name: nil,
                preferred_language: nil
              )
            end
          end
        end

        it 'excludes role and preferred_language when absent' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_not_including(:role, :preferred_language)
            )
          end

          worker.perform(user_without_attrs.id, namespace.id, product_interaction, previous_plan_name)
        end
      end

      context 'when product interaction is for ultimate plan' do
        let(:product_interaction) { 'cart abandonment - SaaS Ultimate' }

        it 'sends lead with ultimate plan_id' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_including(plan_id: 'ultimate-plan-id')
            )
          end

          worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
        end
      end

      context 'when FetchSubscriptionPlansService returns nil' do
        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
            allow(service).to receive(:execute).and_return(nil)
          end
        end

        it 'sends lead with nil plan_id' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_including(plan_id: nil)
            )
          end

          worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
        end
      end

      context 'when no matching plan code is found' do
        let(:plans_data) do
          [Hashie::Mash.new(id: 'other-plan-id', code: 'other')]
        end

        before do
          allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
            allow(service).to receive(:execute).and_return(plans_data)
          end
        end

        it 'sends lead with nil plan_id' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_including(plan_id: nil)
            )
          end

          worker.perform(user.id, namespace.id, product_interaction, previous_plan_name)
        end
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [user.id, namespace.id, product_interaction, previous_plan_name] }
    let(:plans_data) do
      [
        Hashie::Mash.new(id: 'premium-plan-id', code: 'premium'),
        Hashie::Mash.new(id: 'ultimate-plan-id', code: 'ultimate')
      ]
    end

    before do
      allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
        allow(service).to receive(:execute).and_return(plans_data)
      end
      allow_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end
    end
  end

  it 'has the `until_executing` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executing)
  end

  it 'includes scheduled jobs in deduplication' do
    expect(described_class.get_deduplication_options).to include(including_scheduled: true)
  end

  it 'defines the loggable_arguments' do
    expect(described_class.loggable_arguments).to match_array([0, 1, 2, 3])
  end
end
