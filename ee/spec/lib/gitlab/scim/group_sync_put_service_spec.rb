# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Scim::GroupSyncPutService, feature_category: :system_access do
  let(:scim_group_uid) { SecureRandom.uuid }
  let(:service) do
    described_class.new(
      scim_group_uid: scim_group_uid,
      members: members,
      display_name: 'Engineering'
    )
  end

  describe '#execute' do
    context 'with valid members' do
      let_it_be(:user) { create(:user) }
      let_it_be(:identity) { create(:scim_identity, user: user, group: nil) }
      let(:members) do
        [
          { value: identity.extern_uid, display: user.name }
        ]
      end

      it 'schedules the worker to replace members' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user.id], 'replace')

        service.execute
      end

      it 'returns success' do
        allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)

        result = service.execute

        expect(result).to be_success
      end
    end

    context 'with empty members array' do
      let(:members) { [] }

      it 'schedules the worker with empty user IDs' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [], 'replace')

        service.execute
      end
    end

    context 'with non-existent user identities' do
      let(:members) do
        [
          { value: 'non-existent-identity' }
        ]
      end

      it 'schedules the worker with empty user IDs' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [], 'replace')

        service.execute
      end
    end

    context 'with mixed valid and invalid identities' do
      let_it_be(:user) { create(:user) }
      let_it_be(:identity) { create(:scim_identity, user: user, group: nil) }
      let(:members) do
        [
          { value: identity.extern_uid },
          { value: 'non-existent-identity' }
        ]
      end

      it 'schedules the worker with only valid user IDs' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user.id], 'replace')

        service.execute
      end
    end

    context 'with nil members' do
      let(:members) { nil }

      it 'does not schedule the worker' do
        expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

        service.execute
      end

      it 'returns success' do
        result = service.execute

        expect(result).to be_success
      end
    end

    context 'with blank members' do
      let(:members) do
        [
          { value: '' },
          { value: nil },
          {}
        ]
      end

      it 'schedules the worker with empty user IDs after filtering blanks' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [], 'replace')

        service.execute
      end
    end
  end
end
