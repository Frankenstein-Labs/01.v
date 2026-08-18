# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CompromisedPasswords::DetectAndNotifyService, :aggregate_failures, feature_category: :system_access do
  let_it_be(:user) { create(:user) }

  let(:request_password) { user.password }
  let(:check_result) { '1' }
  let(:request) { double(:request, headers: { 'HTTP_EXPOSED_CREDENTIAL_CHECK' => check_result }) } # rubocop: disable RSpec/VerifiedDoubles -- only headers used

  subject(:execute) { perform_enqueued_jobs { described_class.new(user, request_password, request).execute } }

  before do
    allow(Gitlab::Metrics).to receive(:counter).and_call_original
  end

  shared_examples 'record needed' do
    it 'creates a CompromisedPasswordDetection, increments metric, and emails user' do
      expect(Gitlab::Metrics).to receive(:counter)
        .with(
          :compromised_password_detection_notifications_sent,
          'Counter of compromised password detection notifications sent'
        )
        .and_call_original

      expect { subject }
        .to change {
              user.compromised_password_detections.unresolved.count
            }
        .by(1)
        .and change { ActionMailer::Base.deliveries.count }
        .by(1)
    end
  end

  shared_examples 'record not needed' do
    it 'does not create a CompromisedPasswordDetection, increment metric or emails user' do
      expect(Gitlab::Metrics).not_to receive(:counter)
        .with(
          :compromised_password_detection_notifications_sent,
          'Counter of compromised password detection notifications sent'
        )

      expect { subject }
        .to not_change {
              user.compromised_password_detections.unresolved.count
            }
        .and not_change { ActionMailer::Base.deliveries.count }
    end
  end

  context 'when SaaS', :saas do
    context 'when user does not have a CompromisedPasswordDetection' do
      it_behaves_like 'record needed'

      context 'when an error occurs creating detection' do
        before do
          allow_next_instance_of(Users::CompromisedPasswordDetection) do |instance|
            allow(instance)
              .to receive(:persisted?)
              .and_return(false)
          end
        end

        it 'logs the ActiveRecord error' do
          expect(Gitlab::AppLogger).to receive(:error)
            .with(
              hash_including(
                {
                  message: "Failed to create CompromisedPasswordDetection",
                  errors: [],
                  user_id: user.id
                }
              )
            )
            .and_call_original

          execute
        end
      end

      context 'when password for user is incorrect' do
        let(:request_password) { '11111' }

        it_behaves_like 'record not needed'
      end

      context 'when no compromised credential is detected' do
        let(:check_result) { nil }

        it_behaves_like 'record not needed'
      end

      context 'when exact username only is detected' do
        let(:check_result) { '2' }

        it_behaves_like 'record not needed'
      end

      context 'when user does not use local database password for auth' do
        before do
          allow(user).to receive(:password_based_omniauth_user?).and_return(true)
        end

        it_behaves_like 'record not needed'
      end

      context 'when user is locked' do
        let_it_be(:user) { create(:user, :locked) }

        it_behaves_like 'record not needed'
      end
    end

    context 'when user has a CompromisedPasswordDetection' do
      before do
        create(:compromised_password_detection, user: user, resolved_at: resolved_at)
      end

      context 'when detection has been resolved' do
        let(:resolved_at) { 1.month.ago }

        it_behaves_like 'record needed'
      end

      context 'when detection has not yet been resolved' do
        let(:resolved_at) { nil }

        it_behaves_like 'record not needed'
      end
    end
  end

  context 'when self-managed' do
    it_behaves_like 'record not needed'
  end
end
