# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::InstanceEnrollmentService, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(current_user: user) }

  describe '#enroll' do
    context 'when not on GitLab.com' do
      it 'enables the instance setting', :aggregate_failures do
        result = service.enroll

        expect(result).to be_success
        expect(Gitlab::CurrentSettings.secrets_manager_instance_enrolled).to be true
      end

      it 'expires the application settings cache so the new value is visible immediately' do
        expect(Gitlab::CurrentSettings).to receive(:expire_current_application_settings).and_call_original

        service.enroll
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          a_hash_including(
            name: 'secrets_manager_instance_enroll',
            author: user,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            target: an_instance_of(::Gitlab::Audit::InstanceScope),
            message: 'Enrolled instance in Secrets Manager'
          )
        )

        service.enroll
      end

      context 'when instance is already enrolled' do
        before do
          stub_application_setting(secrets_manager_instance_enrolled: true)
        end

        it 'returns an error', :aggregate_failures do
          result = service.enroll

          expect(result).to be_error
          expect(result.message).to eq('Instance is already enrolled.')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          service.enroll
        end
      end
    end

    context 'when on GitLab.com', :saas do
      it 'returns an error', :aggregate_failures do
        result = service.enroll

        expect(result).to be_error
        expect(result.message).to eq('Instance enrollment is only available on self-managed instances.')
      end

      it 'does not enable the instance setting' do
        service.enroll

        expect(Gitlab::CurrentSettings.secrets_manager_instance_enrolled).to be false
      end
    end
  end

  describe '#unenroll' do
    context 'when not on GitLab.com' do
      context 'when instance is enrolled' do
        before do
          Gitlab::CurrentSettings.update!(secrets_manager_instance_enrolled: true)
        end

        it 'disables the instance setting', :aggregate_failures do
          result = service.unenroll

          expect(result).to be_success
          expect(Gitlab::CurrentSettings.secrets_manager_instance_enrolled).to be false
        end

        it 'expires the application settings cache so the new value is visible immediately' do
          expect(Gitlab::CurrentSettings).to receive(:expire_current_application_settings).and_call_original

          service.unenroll
        end

        it 'creates an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            a_hash_including(
              name: 'secrets_manager_instance_unenroll',
              author: user,
              scope: an_instance_of(::Gitlab::Audit::InstanceScope),
              target: an_instance_of(::Gitlab::Audit::InstanceScope),
              message: 'Unenrolled instance from Secrets Manager'
            )
          )

          service.unenroll
        end
      end

      context 'when instance is not enrolled' do
        it 'returns a not found error', :aggregate_failures do
          result = service.unenroll

          expect(result).to be_error
          expect(result.message).to eq('Instance is not enrolled.')
          expect(result.reason).to eq(:not_found)
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          service.unenroll
        end
      end
    end

    context 'when on GitLab.com', :saas do
      it 'returns an error', :aggregate_failures do
        result = service.unenroll

        expect(result).to be_error
        expect(result.message).to eq('Instance enrollment is only available on self-managed instances.')
      end
    end
  end
end
