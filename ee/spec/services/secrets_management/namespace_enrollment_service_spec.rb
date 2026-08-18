# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::NamespaceEnrollmentService, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  subject(:service) { described_class.new(group, current_user: user) }

  shared_examples 'enrollment not allowed' do |action|
    it 'returns a forbidden error', :aggregate_failures do
      result = service.public_send(action)

      expect(result).to be_error
      expect(result.message).to eq('Namespace enrollment is not allowed.')
      expect(result.reason).to eq(:forbidden)
    end

    it 'does not create an audit event' do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      service.public_send(action)
    end
  end

  describe '#enroll' do
    context 'when on GitLab.com', :saas do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it 'creates a namespace enrollment', :aggregate_failures do
        result = service.enroll

        expect(result).to be_success
        enrollment = result.payload[:enrollment]
        expect(enrollment.namespace).to eq(group)
      end

      it 'persists the enrollment record' do
        expect { service.enroll }
          .to change { SecretsManagement::NamespaceEnrollment.count }.by(1)
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          a_hash_including(
            name: 'secrets_manager_namespace_enroll',
            author: user,
            scope: group,
            target: group,
            message: 'Enrolled namespace in Secrets Manager'
          )
        )

        service.enroll
      end

      context 'when the paid experience is not enabled for the namespace' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: false)
        end

        it 'marks the enrollment as beta' do
          expect(service.enroll.payload[:enrollment].beta).to be true
        end
      end

      context 'when the paid experience is enabled for the namespace' do
        before do
          stub_feature_flags(secrets_manager_paid_experience: group)
        end

        it 'does not mark the enrollment as beta' do
          expect(service.enroll.payload[:enrollment].beta).to be false
        end
      end

      context 'when namespace is already enrolled' do
        before do
          create(:secrets_manager_namespace_enrollment, namespace: group)
        end

        it 'returns an error', :aggregate_failures do
          result = service.enroll

          expect(result).to be_error
          expect(result.message).to eq('Namespace is already enrolled.')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          service.enroll
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:user_namespace) { create(:user_namespace) }

        subject(:service) { described_class.new(user_namespace, current_user: user) }

        it_behaves_like 'enrollment not allowed', :enroll

        it 'does not create an enrollment record' do
          expect { service.enroll }
            .not_to change { SecretsManagement::NamespaceEnrollment.count }
        end
      end

      context 'when namespace is not a root group' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }

        it 'rejects a subgroup', :aggregate_failures do
          result = described_class.new(subgroup, current_user: user).enroll

          expect(result).to be_error
          expect(result.message).to eq('Namespace enrollment is not allowed.')
        end

        it 'rejects a deeply nested subgroup', :aggregate_failures do
          result = described_class.new(nested_subgroup, current_user: user).enroll

          expect(result).to be_error
          expect(result.message).to eq('Namespace enrollment is not allowed.')
        end

        it 'does not create an enrollment record' do
          expect { described_class.new(subgroup, current_user: user).enroll }
            .not_to change { SecretsManagement::NamespaceEnrollment.count }
        end
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it_behaves_like 'enrollment not allowed', :enroll
      end

      context 'when enrollment feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
        end

        it_behaves_like 'enrollment not allowed', :enroll
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it_behaves_like 'enrollment not allowed', :enroll

      it 'does not create an enrollment record' do
        expect { service.enroll }
          .not_to change { SecretsManagement::NamespaceEnrollment.count }
      end
    end
  end

  describe '#unenroll' do
    context 'when on GitLab.com', :saas do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      context 'when namespace is enrolled' do
        before do
          create(:secrets_manager_namespace_enrollment, namespace: group)
        end

        it 'deletes the enrollment record', :aggregate_failures do
          result = service.unenroll

          expect(result).to be_success
          expect(SecretsManagement::NamespaceEnrollment.for_namespace(group)).not_to exist
        end

        it 'decrements the enrollment count' do
          expect { service.unenroll }
            .to change { SecretsManagement::NamespaceEnrollment.count }.by(-1)
        end

        it 'creates an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            a_hash_including(
              name: 'secrets_manager_namespace_unenroll',
              author: user,
              scope: group,
              target: group,
              message: 'Unenrolled namespace from Secrets Manager'
            )
          )

          service.unenroll
        end
      end

      context 'when namespace is not enrolled' do
        it 'returns a not found error', :aggregate_failures do
          result = service.unenroll

          expect(result).to be_error
          expect(result.message).to eq('Enrollment not found.')
          expect(result.reason).to eq(:not_found)
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          service.unenroll
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:user_namespace) { create(:user_namespace) }

        subject(:service) { described_class.new(user_namespace, current_user: user) }

        it_behaves_like 'enrollment not allowed', :unenroll
      end

      context 'when namespace is not a root group' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        subject(:service) { described_class.new(subgroup, current_user: user) }

        it_behaves_like 'enrollment not allowed', :unenroll
      end

      context 'when license is not available' do
        before do
          stub_licensed_features(native_secrets_management: false)
        end

        it_behaves_like 'enrollment not allowed', :unenroll
      end

      context 'when enrollment feature flag is disabled' do
        before do
          stub_feature_flags(secrets_manager_namespace_enrollment: false)
        end

        it_behaves_like 'enrollment not allowed', :unenroll
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_licensed_features(native_secrets_management: true)
        stub_feature_flags(secrets_manager_namespace_enrollment: group)
      end

      it_behaves_like 'enrollment not allowed', :unenroll
    end
  end
end
