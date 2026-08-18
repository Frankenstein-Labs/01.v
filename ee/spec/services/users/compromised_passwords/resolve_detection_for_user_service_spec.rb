# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CompromisedPasswords::ResolveDetectionForUserService, :aggregate_failures, feature_category: :system_access do
  subject(:execute) { described_class.new(user).execute }

  let_it_be(:user) { create(:user) }

  before do
    allow(Gitlab::Metrics).to receive(:counter).and_call_original
  end

  shared_examples 'resolve needed' do
    it 'resolve detection and increments metric' do
      expect(Gitlab::Metrics).to receive(:counter)
        .with(
          :compromised_password_detection_passwords_changed,
          'Counter of passwords changed after compromised password detection'
        )
        .and_call_original

      expect { subject }
        .to change {
              user.compromised_password_detections.unresolved.count
            }
        .by(-1)
    end
  end

  shared_examples 'resolve not needed' do
    it 'does not resolve detection or increments metric' do
      expect(Gitlab::Metrics).not_to receive(:counter)
        .with(
          :compromised_password_detection_passwords_changed,
          'Counter of passwords changed after compromised password detection'
        )

      expect { subject }
        .to not_change {
              user.compromised_password_detections.unresolved.count
            }
    end
  end

  context 'when SaaS', :saas do
    context 'when user does not have a CompromisedPasswordDetection' do
      it_behaves_like 'resolve not needed'
    end

    context 'when user has a CompromisedPasswordDetection callout' do
      before do
        create(:compromised_password_detection, user: user, resolved_at: resolved_at)
      end

      context 'when CompromisedPasswordDetection has been resolved' do
        let(:resolved_at) { 1.month.ago }

        it_behaves_like 'resolve not needed'
      end

      context 'when CompromisedPasswordDetection has not yet been resolved' do
        let(:resolved_at) { nil }

        it_behaves_like 'resolve needed'

        context 'when an error occurs creating detection' do
          before do
            allow_next_found_instance_of(Users::CompromisedPasswordDetection) do |detection|
              allow(detection).to receive(:save).and_return(false)
            end
          end

          it 'logs the ActiveRecord error' do
            expect(Gitlab::AppLogger).to receive(:error)
              .with(
                hash_including(
                  {
                    message: "Failed to update CompromisedPasswordDetection",
                    errors: [],
                    compromised_password_detection_id: anything,
                    user_id: user.id
                  }
                )
              )
              .and_call_original

            execute
          end
        end
      end
    end
  end

  context 'when self-managed' do
    it_behaves_like 'resolve not needed'
  end
end
