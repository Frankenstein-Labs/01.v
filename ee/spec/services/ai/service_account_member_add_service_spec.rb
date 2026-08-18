# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ServiceAccountMemberAddService, feature_category: :duo_agent_platform do
  let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let_it_be(:project) { create(:project) }
  let(:service) { described_class.new(project, service_account) }

  describe '#execute' do
    context 'when the service account is not a member of the project' do
      it 'adds the service account as a developer and syncs ProjectAuthorization immediately' do
        expect { service.execute }.to change { project.members.count }.by(1)

        member = project.members.last
        expect(member.user_id).to eq(service_account.id)
        expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
        expect(
          ProjectAuthorization.where(
            user_id: service_account.id, project_id: project.id,
            access_level: Gitlab::Access::DEVELOPER)
        ).to exist
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to be_a(ProjectMember)
      end
    end

    context 'when the service account is already a member of the project' do
      before_all do
        project.add_developer(service_account)
      end

      it 'does not add a new membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns a success response with a message' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq("Membership already exists. Nothing to do.")
      end
    end

    context 'when the service account is not found' do
      let(:service_account) { nil }

      it 'does not add a new membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns an error response with a message' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Service account user not found")
      end
    end

    context 'when adding project member fails to persist with validation errors' do
      let(:member) { build(:project_member, project: project, user: service_account) }

      before do
        member.errors.add(:base, 'Validation error')
        allow(project).to receive(:add_member).and_return(member)
        allow(member).to receive(:persisted?).and_return(false)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Failed to add service account as developer")
      end

      it 'logs the error with validation details' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'Failed to add service account as developer',
            project_id: project.id,
            service_account_user_id: service_account.id,
            error_details: 'Member validation/authorization errors: Validation error'
          )
        )

        service.execute
      end
    end

    context 'when adding project member fails to persist without validation errors' do
      let(:member) { build(:project_member, project: project, user: service_account) }

      before do
        allow(project).to receive(:add_member).and_return(member)
        allow(member).to receive(:persisted?).and_return(false)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Failed to add service account as developer")
      end

      it 'logs the error indicating save or approval failure' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'Failed to add service account as developer',
            project_id: project.id,
            service_account_user_id: service_account.id,
            error_details: 'Member object returned but not persisted (possible save failure or approval failure)'
          )
        )

        service.execute
      end
    end
  end

  context 'when adding developer returns false' do
    before do
      allow(project).to receive(:add_member).and_return(false)
    end

    it 'does not add a new membership' do
      expect { service.execute }.not_to change { project.members.count }
    end

    it 'returns an error response' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq("Failed to add service account as developer")
    end

    it 'logs the error with group membership lock details' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          message: 'Failed to add service account as developer',
          project_id: project.id,
          service_account_user_id: service_account.id,
          error_details: 'add_member returned false (group_member_lock is enabled and user is not a bot)'
        )
      )

      service.execute
    end
  end

  context 'when adding developer returns nil' do
    before do
      allow(project).to receive(:add_member).and_return(nil)
    end

    it 'does not add a new membership' do
      expect { service.execute }.not_to change { project.members.count }
    end

    it 'returns an error response' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq("Failed to add service account as developer")
    end

    it 'logs the error with appropriate details' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          message: 'Failed to add service account as developer',
          error_details: 'add_member returned nil (empty result array or transaction failure)'
        )
      )

      service.execute
    end
  end

  context 'when adding developer returns unexpected type' do
    let(:unexpected_object) do
      object = Object.new
      allow(object).to receive(:persisted?).and_return(false)
      object
    end

    before do
      allow(project).to receive(:add_member).and_return(unexpected_object)
    end

    it 'does not add a new membership' do
      expect { service.execute }.not_to change { project.members.count }
    end

    it 'returns an error response' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq("Failed to add service account as developer")
    end

    it 'logs the error with unexpected return type' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          message: 'Failed to add service account as developer',
          error_details: 'Unexpected return type from add_member: Object'
        )
      )

      service.execute
    end
  end

  context 'when project has a group with membership lock' do
    let_it_be(:group) { create(:group, membership_lock: true) }
    let_it_be(:project_with_group) { create(:project, group: group) }
    let(:service) { described_class.new(project_with_group, service_account) }

    before do
      allow(project_with_group).to receive(:add_member).and_return(false)
    end

    it 'logs group membership lock status' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          group_membership_lock: true,
          root_ancestor_membership_lock: true
        )
      )

      service.execute
    end
  end

  context 'when project has a root ancestor with membership lock' do
    let_it_be(:root_group) { create(:group, membership_lock: true) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project_with_ancestor) { create(:project, group: subgroup) }
    let(:service) { described_class.new(project_with_ancestor, service_account) }

    before do
      allow(project_with_ancestor).to receive(:add_member).and_return(false)
    end

    it 'logs root ancestor membership lock status' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          group_membership_lock: true,
          root_ancestor_membership_lock: true
        )
      )

      service.execute
    end
  end

  context 'when error extraction itself raises an error' do
    before do
      allow(project).to receive(:add_member).and_return(false)
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:extract_error_details).and_raise(StandardError, 'Extraction error')
      end
    end

    it 'logs a fallback error message and does not raise' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        hash_including(
          message: 'Failed to add service account as developer (logging error)',
          project_id: project.id,
          service_account_user_id: service_account.id,
          logging_error: 'StandardError: Extraction error'
        )
      )

      expect { service.execute }.not_to raise_error
    end

    it 'returns an error response' do
      allow(Gitlab::AppLogger).to receive(:error)

      result = service.execute

      expect(result).to be_error
      expect(result.message).to eq("Failed to add service account as developer")
    end
  end
end
