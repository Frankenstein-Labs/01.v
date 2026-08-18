# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Keys::ExpiryNotificationService, feature_category: :source_code_management do
  let(:params) { { keys: user.keys, expiring_soon: expiring_soon } }

  subject { described_class.new(user, params) }

  shared_examples 'sends a notification' do |notification_method, notified_column|
    it 'sends email to the user', :aggregate_failures do
      expect(NotificationService).to receive(:new).and_call_original

      perform_enqueued_jobs do
        subject.execute
      end

      should_email(user)
    end

    it 'uses notification service to send email to the user' do
      expect_next_instance_of(NotificationService) do |notification_service|
        expect(notification_service).to receive(notification_method).with(key.user, [key.fingerprint])
      end

      subject.execute
    end

    it 'creates todo' do
      expect(TodoService).to receive(:new).and_call_original

      perform_enqueued_jobs do
        expect { subject.execute }.to change { user.todos.count }.by(1)
      end
    end

    it 'updates notified column' do
      expect { subject.execute }.to change { key.reload.public_send(notified_column) }
    end
  end

  shared_examples 'does not send notification' do |notified_column|
    it 'does not send email to the user', :aggregate_failures do
      expect(NotificationService).not_to receive(:new)

      perform_enqueued_jobs do
        subject.execute
      end

      should_not_email(user)
    end

    it 'does not create todo', :aggregate_failures do
      expect(TodoService).not_to receive(:new)

      perform_enqueued_jobs do
        expect { subject.execute }.not_to change { user.todos.count }
      end
    end

    it 'does not update notified column' do
      expect { subject.execute }.not_to change { key.reload.public_send(notified_column) }
    end
  end

  context 'for enterprise users', :saas do
    before do
      stub_licensed_features(disable_ssh_keys: true)
      stub_saas_features(disable_ssh_keys: true)
    end

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group) }

    context 'with key expiring today', :mailer do
      let_it_be_with_reload(:key) { create(:key, :expired_today, user: user) }

      let(:expiring_soon) { false }

      context 'when user has permission to receive notification' do
        it_behaves_like 'sends a notification', :ssh_key_expired, :expiry_notification_delivered_at

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it_behaves_like 'does not send notification', :expiry_notification_delivered_at
        end
      end
    end

    context 'with key expiring soon', :mailer do
      let_it_be_with_reload(:key) { create(:key, expires_at: 3.days.from_now, user: user) }

      let(:expiring_soon) { true }

      context 'when user has permission to receive notification' do
        it_behaves_like 'sends a notification', :ssh_key_expiring_soon, :before_expiry_notification_delivered_at

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it_behaves_like 'does not send notification', :before_expiry_notification_delivered_at
        end
      end
    end
  end
end
