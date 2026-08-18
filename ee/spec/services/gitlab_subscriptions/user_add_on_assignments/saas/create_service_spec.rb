# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UserAddOnAssignments::Saas::CreateService, feature_category: :seat_cost_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:user) { create(:user, developer_of: namespace) }

  subject(:response) do
    described_class.new(add_on_purchase: add_on_purchase, user: user).execute
  end

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  describe '#execute' do
    shared_examples 'success response' do |product_interaction = 'duo_pro_add_on_seat_assigned'|
      it 'creates an iterable trigger' do
        params = {
          first_name: user.first_name,
          last_name: user.last_name,
          work_email: user.email,
          namespace_id: namespace.id,
          product_interaction: product_interaction,
          existing_plan: namespace.actual_plan_name,
          preferred_language: 'English',
          opt_in: user.onboarding_status_email_opt_in
        }.stringify_keys

        expect(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async).with(params)

        response
      end

      it 'invokes an async onboarding progress update' do
        expect(Onboarding::ProgressService).to receive(:async).with(namespace.id, 'duo_seat_assigned')

        response
      end
    end

    shared_examples 'without notification' do
      it 'does not create an iterable trigger' do
        expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

        response
      end

      it 'does not invoke an async onboarding progress update' do
        expect(Onboarding::ProgressService).not_to receive(:async)

        response
      end
    end

    it_behaves_like 'success response'

    context 'when user is already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it_behaves_like 'without notification'
    end

    context 'with add_on other than Duo' do
      let(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }
      let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }

      it_behaves_like 'without notification'
    end

    context 'with a Duo Enterprise add-on purchase' do
      let(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
      let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }

      it_behaves_like 'success response', 'duo_enterprise_add_on_seat_assigned'
    end
  end
end
