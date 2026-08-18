# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SelfManaged::CreateWelcomeProductInteractionService, feature_category: :onboarding do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user, first_name: 'Jane', last_name: 'Doe') }
    let(:instance_uuid) { 'test-instance-uuid' }
    let(:now) { Date.current }
    let(:expected_params) do
      {
        lead: {
          first_name: 'Jane',
          last_name: 'Doe',
          email: user.email,
          company_name: 'Acme Corp',
          product_interaction: 'SM Welcome Flow No Trial Contact',
          instance_id: instance_uuid,
          country: 'US',
          hostname: 'gitlab.example.com',
          sign_up_date: now.iso8601
        }
      }
    end

    before_all do
      user.user_detail.update!(
        company: 'Acme Corp',
        onboarding_status: { 'email_opt_in' => true, 'country' => 'US' }
      )
    end

    before do
      stub_application_setting(uuid: instance_uuid)
      stub_config_setting(host: 'gitlab.example.com')
      travel_to(now)
    end

    subject(:execute) { described_class.new(user: user).execute }

    context 'when the submission succeeds' do
      before do
        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:create_self_managed_welcome_contact)
          .with(expected_params)
          .and_return({ success: true })
      end

      it 'returns success' do
        expect(execute).to be_success
      end

      it 'calls create_self_managed_welcome_contact with the expected params' do
        execute

        expect(Gitlab::SubscriptionPortal::Client)
          .to have_received(:create_self_managed_welcome_contact).with(expected_params)
      end

      it 'sends the correct product_interaction value' do
        execute

        expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
          .with(lead: hash_including(product_interaction: 'SM Welcome Flow No Trial Contact'))
      end

      context 'when user has an unconfirmed email' do
        let(:unconfirmed_email) { 'new-email@example.com' }
        let(:expected_params) { { lead: super()[:lead].merge(email: unconfirmed_email) } }

        before do
          allow(user).to receive(:unconfirmed_email).and_return(unconfirmed_email)
        end

        it 'uses the unconfirmed email address' do
          execute

          expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
            .with(lead: hash_including(email: unconfirmed_email))
        end
      end

      it 'includes the instance UUID' do
        execute

        expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
          .with(lead: hash_including(instance_id: instance_uuid))
      end

      it 'includes the country from onboarding status' do
        execute

        expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
          .with(lead: hash_including(country: 'US'))
      end

      context 'when country is not set' do
        let(:expected_params) { { lead: super()[:lead].except(:country) } }

        before do
          user.user_detail.update!(onboarding_status: { 'email_opt_in' => true })
        end

        it 'omits the country field' do
          execute

          expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
            .with(lead: hash_not_including(:country))
        end
      end

      it 'includes the hostname' do
        execute

        expect(Gitlab::SubscriptionPortal::Client).to have_received(:create_self_managed_welcome_contact)
          .with(lead: hash_including(hostname: 'gitlab.example.com'))
      end
    end

    context 'when the submission fails with an error message' do
      before do
        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:create_self_managed_welcome_contact)
          .and_return({ success: false, data: { errors: 'email is invalid' } })
      end

      it 'returns the error', :aggregate_failures do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('email is invalid')
        expect(result.reason).to eq(:submission_failed)
      end
    end

    context 'when the submission fails without an error message' do
      before do
        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:create_self_managed_welcome_contact)
          .and_return({ success: false })
      end

      it 'returns a default error message', :aggregate_failures do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('Submission failed')
        expect(result.reason).to eq(:submission_failed)
      end
    end
  end
end
