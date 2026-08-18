# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::ProvisionServiceAccountService,
  feature_category: :dependency_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:project) { create(:project, group: group, organization: organization) }

  subject(:execute) { described_class.new(project: project).execute }

  before do
    stub_ee_application_setting(
      allow_top_level_group_owners_to_create_service_accounts: true
    )
    allow_next_instance_of(Namespaces::ServiceAccounts::ProjectCreateService) do |svc|
      allow(svc).to receive(:can_create_service_account?).and_return(true)
    end
  end

  describe '#execute' do
    context 'when no service account exists yet' do
      it 'creates a new service account user' do
        expect { execute }.to change { User.service_accounts.count }.by(1)
      end

      it 'returns a success ServiceResponse with the new user' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_success
        expect(result.payload[:user]).to be_a(User)
        expect(result.payload[:user]).to be_service_account
      end

      it 'names the account correctly' do
        expect(execute.payload[:user].name).to eq(described_class::SERVICE_ACCOUNT_NAME)
      end

      it 'provisions the account for the project' do
        service_account = execute.payload[:user]

        expect(service_account.user_detail.provisioned_by_project_id).to eq(project.id)
      end

      it 'adds the service account as Guest on the project' do
        service_account = execute.payload[:user]

        expect(project.member(service_account).access_level).to eq(Gitlab::Access::GUEST)
      end

      it 'immediately syncs project authorizations' do
        expect(project).to receive(:add_member).with(
          anything,
          :guest,
          immediately_sync_authorizations: true
        ).and_call_original

        execute
      end
    end

    context 'when a service account already exists' do
      let_it_be(:existing_user) { create(:user, :service_account) }

      before do
        allow(project).to receive(:dependency_management_service_account)
          .and_return(existing_user)
      end

      it 'does not create a new user' do
        expect { execute }.not_to change { User.service_accounts.count }
      end

      it 'returns a success ServiceResponse with the existing user' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_success
        expect(result.payload[:user]).to eq(existing_user)
      end

      it 'does not call ProjectCreateService' do
        expect(Namespaces::ServiceAccounts::ProjectCreateService).not_to receive(:new)

        execute
      end
    end

    context 'when a service account exists for a different project' do
      let_it_be(:other_project) { create(:project, group: group, organization: organization) }

      before do
        described_class.new(project: other_project).execute
      end

      it 'creates a new service account for this project' do
        expect { execute }.to change { User.service_accounts.count }.by(1)
      end

      it 'provisions the new account for the correct project' do
        service_account = execute.payload[:user]

        expect(service_account.user_detail.provisioned_by_project_id).to eq(project.id)
      end
    end

    context 'when service account creation fails' do
      before do
        allow_next_instance_of(Namespaces::ServiceAccounts::ProjectCreateService) do |svc|
          allow(svc).to receive(:execute)
            .and_return({ status: :error, message: 'quota exceeded' })
        end
      end

      it 'returns an error ServiceResponse' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
      end

      it 'returns a generic error message' do
        expect(execute.message).to eq('Failed to create service account')
      end

      it 'logs the detailed failure reason' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'Failed to create dependency management service account',
            reason: 'quota exceeded',
            project_id: project.id
          )
        )

        execute
      end

      it 'does not add any member to the project' do
        expect { execute }.not_to change { project.members.count }
      end
    end

    context 'when add_member returns nil' do
      before do
        allow(project).to receive(:add_member).and_return(nil)
      end

      it 'returns an error ServiceResponse' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
      end

      it 'includes a meaningful nil-specific message' do
        expect(execute.message).to include('add_member returned nil')
      end
    end

    context 'when add_member returns an unpersisted member' do
      let(:invalid_member) do
        instance_double(
          ProjectMember,
          nil?: false,
          persisted?: false,
          active?: false,
          errors: instance_double(ActiveModel::Errors, full_messages: ['Access level is not included in the list'])
        )
      end

      before do
        allow(project).to receive(:add_member).and_return(invalid_member)
      end

      it 'returns an error ServiceResponse' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
      end

      it 'includes the member validation errors in the message' do
        expect(execute.message).to include('Failed to add service account as guest')
      end
    end

    context 'when add_member returns a persisted but inactive member (user cap or membership lock)' do
      let(:pending_member) do
        instance_double(
          ProjectMember,
          nil?: false,
          persisted?: true,
          active?: false,
          errors: instance_double(ActiveModel::Errors, full_messages: [])
        )
      end

      before do
        allow(project).to receive(:add_member).and_return(pending_member)
      end

      it 'returns an error ServiceResponse' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
      end

      it 'includes a message about the member not being active' do
        expect(execute.message).to include('member is not active')
      end
    end

    context 'when lock is obtained' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "dependency_management:provision_service_account:#{project.id}" }

      before do
        stub_exclusive_lease(lease_key)
      end

      it 'creates a service account within the lock' do
        service = described_class.new(project: project)

        Gitlab::ExclusiveLease.skipping_transaction_check do
          expect(service).to receive(:in_lock)
            .with(lease_key, ttl: described_class::LEASE_TIMEOUT, retries: 10, sleep_sec: 0.5.seconds)
            .and_call_original

          result = service.execute

          expect(result).to be_success
          expect(result.payload[:user]).to be_service_account
        end
      end
    end

    context 'when lock cannot be obtained' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "dependency_management:provision_service_account:#{project.id}" }

      before do
        stub_exclusive_lease_taken(lease_key)
      end

      it 'returns an error ServiceResponse' do
        service = described_class.new(project: project)

        expect(service).to receive(:in_lock)
          .with(lease_key, ttl: described_class::LEASE_TIMEOUT, retries: 10, sleep_sec: 0.5.seconds)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        result = service.execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
        expect(result.message).to eq('Could not obtain lock for service account provisioning')
      end
    end

    context 'when admin bot is not found for the organization' do
      before do
        allow(Users::Internal).to receive(:in_organization)
          .with(project.organization)
          .and_return(Users::Internal)
        allow(Users::Internal).to receive(:admin_bot).and_return(nil)
      end

      it 'returns an error ServiceResponse' do
        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
      end

      it 'returns a descriptive error message' do
        expect(execute.message).to eq('Admin bot not found for the project organization')
      end

      it 'does not create a service account' do
        expect { execute }.not_to change { User.service_accounts.count }
      end

      it 'does not add any member to the project' do
        expect { execute }.not_to change { project.members.count }
      end
    end

    context 'when another process creates the account while waiting for the lock' do
      let_it_be(:race_winner_user) { create(:user, :service_account) }

      before do
        reset_project = instance_double(Project, dependency_management_service_account: race_winner_user)
        allow(project).to receive_messages(dependency_management_service_account: nil, reset: reset_project)
      end

      it 'returns the existing account without creating a new one' do
        expect(Namespaces::ServiceAccounts::ProjectCreateService).not_to receive(:new)

        result = execute

        expect(result).to be_success
        expect(result.payload[:user]).to eq(race_winner_user)
      end
    end

    context 'when cleanup of orphaned user fails after add_member returns nil' do
      let(:service_account) { create(:user, :service_account) }

      before do
        allow_next_instance_of(Namespaces::ServiceAccounts::ProjectCreateService) do |svc|
          allow(svc).to receive(:execute)
            .and_return({ status: :success, user: service_account })
        end

        allow(project).to receive(:add_member).and_return(nil)
        allow(service_account).to receive(:destroy).and_raise(StandardError, 'destroy failed')
      end

      it 'logs the cleanup failure and still returns the add_member error' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'Failed to clean up orphaned dependency management service account',
            user_id: service_account.id,
            project_id: project.id,
            error: 'destroy failed'
          )
        )

        result = execute

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
        expect(result.message).to include('add_member returned nil')
      end

      it 'does not raise the StandardError' do
        expect { execute }.not_to raise_error
      end
    end
  end
end
