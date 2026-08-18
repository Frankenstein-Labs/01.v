# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::CreateTrialService, feature_category: :acquisition do
  let_it_be_with_reload(:user) { create(:user, preferred_language: 'en') }

  let(:params) do
    {
      first_name: 'John',
      last_name: 'Doe',
      email_address: 'john@example.com',
      company_name: 'ACME Corp',
      country: 'US',
      state: 'CA',
      consent_to_marketing: '1'
    }
  end

  let(:activation_code) { 'test-activation-code-123' }

  subject(:execute) { described_class.new(params: params, user: user).execute }

  describe '#execute' do
    context 'when trial creation and activation succeed' do
      before do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                       .and_return({ success: true,
data: { 'activation_code' => activation_code } })

        allow_next_instance_of(GitlabSubscriptions::ActivateService) do |activate_service|
          allow(activate_service).to receive(:execute)
                                       .with(activation_code)
                                       .and_return({ success: true })
        end
      end

      it 'returns a success response' do
        expect(execute).to be_success
      end

      it 'calls CustomersDot with correct parameters' do
        expect(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                        .with(hash_including(
                                                          trial: hash_including(
                                                            name: 'John Doe',
                                                            email: 'john@example.com',
                                                            language: 'en',
                                                            company: 'ACME Corp',
                                                            country: 'US',
                                                            state: 'CA',
                                                            consent_to_marketing: '1'
                                                          )
                                                        ))

        execute
      end

      it 'activates license with returned activation code' do
        expect_next_instance_of(GitlabSubscriptions::ActivateService) do |activate_service|
          expect(activate_service).to receive(:execute).with(activation_code).and_return({ success: true })
        end

        execute
      end

      it 'uses the user preferred language' do
        user.update!(preferred_language: 'fr')

        expect(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                        .with(hash_including(trial: hash_including(language: 'fr')))

        execute
      end
    end

    context 'when CustomersDot trial creation fails' do
      context 'with email taken error' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                         .and_return({
                                                           success: false,
                                                           data: {
                                                             error_attribute_map: {
                                                               base: ['only_one_trial_per_email_and_type']
                                                             }
                                                           }
                                                         })
        end

        it 'returns an error response with form_failure reason' do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq(:form_failure)
          expect(result.message).to include('already registered')
        end

        it 'tracks the duplicate email error event' do
          expect { execute }
            .to trigger_internal_events('sm_trial_create_form_duplicate_email_error').with(user: user)
        end

        it 'does not attempt activation' do
          expect(GitlabSubscriptions::ActivateService).not_to receive(:new)

          execute
        end
      end

      context 'with generic error' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                         .and_return({
                                                           success: false,
                                                           data: { error_attribute_map: { base: ['generic_error'] } }
                                                         })
        end

        it 'returns an error response with generic_failure reason' do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq(:generic_failure)
          expect(result.message).to include('GitLab Support')
        end

        it 'does not attempt activation' do
          expect(GitlabSubscriptions::ActivateService).not_to receive(:new)

          execute
        end
      end

      context 'when data is nil' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                         .and_return({ success: false, data: nil })
        end

        it 'returns an error response with generic_failure reason' do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq(:generic_failure)
          expect(result.message).to include('GitLab Support')
        end
      end

      context 'when error_attribute_map is missing' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                         .and_return({ success: false, data: {} })
        end

        it 'returns an error response with generic_failure reason' do
          result = execute

          expect(result).to be_error
          expect(result.reason).to eq(:generic_failure)
          expect(result.message).to include('GitLab Support')
        end
      end
    end

    context 'when license activation fails' do
      before do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_self_managed_ultimate_trial)
                                                       .and_return({ success: true,
data: { 'activation_code' => activation_code } })

        allow_next_instance_of(GitlabSubscriptions::ActivateService) do |activate_service|
          allow(activate_service).to receive(:execute)
                                       .and_return({ success: false, errors: ['Activation code is invalid'] })
        end
      end

      it 'returns generic error' do
        result = execute

        expect(result).to be_error
        expect(result.reason).to eq(:generic_failure)
        expect(result.message).to include('GitLab Support')
      end
    end
  end
end
