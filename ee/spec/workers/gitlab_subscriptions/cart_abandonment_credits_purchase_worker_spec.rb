# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CartAbandonmentCreditsPurchaseWorker, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }

  let(:previous_monthly_commitment_credits) { '0' }
  let(:monthly_commitment_credits) { '100' }

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when user does not exist' do
      it 'returns early without calling service' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(non_existing_record_id, namespace.id, previous_monthly_commitment_credits)
      end
    end

    context 'when namespace does not exist' do
      it 'returns early without calling service' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(user.id, non_existing_record_id, previous_monthly_commitment_credits)
      end
    end

    context 'when previous credits are 0 and namespace has active gitlab credits add-on' do
      before do
        allow(Namespace).to receive(:find_by_id).with(namespace.id).and_return(namespace)
        allow(namespace).to receive(:has_active_gitlab_credits_add_on?).and_return(true)
      end

      it 'does not send lead' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(user.id, namespace.id, previous_monthly_commitment_credits)
      end
    end

    context 'when current credits exceed previous credits' do
      before do
        allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { total_credits: monthly_commitment_credits }))
        end
      end

      it 'does not send lead' do
        expect(GitlabSubscriptions::CreateHandRaiseLeadService).not_to receive(:new)

        worker.perform(user.id, namespace.id, previous_monthly_commitment_credits)
      end
    end

    context 'when user did not purchase credits' do
      before do
        allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { total_credits: previous_monthly_commitment_credits }))
        end
      end

      it 'sends lead with first-purchase-credits glm_content' do
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expect(service).to receive(:execute).with(
            hash_including(
              product_interaction: 'cart abandonment - DAP monthly commit',
              work_email: user.email,
              opt_in: user.onboarding_status_email_opt_in,
              namespace_id: namespace.id,
              existing_plan: namespace.actual_plan_name,
              skip_country_validation: true,
              glm_source: 'gitlab.com',
              glm_content: 'first-purchase-credits'
            )
          )
        end

        worker.perform(user.id, namespace.id, previous_monthly_commitment_credits)
      end

      context 'when it is an increase credits purchase' do
        before do
          allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
            allow(service).to receive(:execute)
              .and_return(ServiceResponse.success(payload: { total_credits: monthly_commitment_credits }))
          end
        end

        it 'sends lead with increase-credits-purchase glm_content' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_including(
                glm_source: 'gitlab.com',
                glm_content: 'increase-credits-purchase'
              )
            )
          end

          worker.perform(user.id, namespace.id, monthly_commitment_credits)
        end
      end

      context 'with optional user attributes' do
        let(:role_name) { 'software_developer' }
        let(:preferred_language) { 'zh_CN' }
        let(:trimmed_language_name) { 'Chinese, Simplified' }

        before do
          allow(User).to receive(:find_by_id).with(user.id).and_return(user)

          allow(user).to receive_messages(
            onboarding_status_role_name: role_name,
            preferred_language: preferred_language
          )

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

          worker.perform(user.id, namespace.id, monthly_commitment_credits)
        end
      end

      context 'without optional user attributes' do
        before do
          allow(User).to receive(:find_by_id).with(user.id).and_return(user)
          allow(user).to receive_messages(onboarding_status_role_name: nil, preferred_language: nil)
        end

        it 'excludes role and preferred_language when absent' do
          expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
            expect(service).to receive(:execute).with(
              hash_not_including(:role, :preferred_language)
            )
          end

          worker.perform(user.id, namespace.id, monthly_commitment_credits)
        end
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [user.id, namespace.id, previous_monthly_commitment_credits] }

    before do
      allow_next_instance_of(GitlabSubscriptions::FetchMonthlyCommitmentService) do |service|
        allow(service).to receive(:execute)
          .and_return(ServiceResponse.success(payload: { total_credits: monthly_commitment_credits }))
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
    expect(described_class.loggable_arguments).to match_array([0, 1, 2])
  end
end
