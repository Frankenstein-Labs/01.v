# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Scim::GroupSyncPatchService, feature_category: :system_access do
  let(:scim_group_uid) { SecureRandom.uuid }
  let(:service) { described_class.new(scim_group_uid: scim_group_uid, operations: operations) }

  describe '#execute' do
    context 'with add operation' do
      let_it_be(:user) { create(:user) }
      let_it_be(:identity) { create(:scim_identity, user: user, group: nil) }
      let(:operations) do
        [
          {
            op: 'Add',
            path: 'members',
            value: [{ value: identity.extern_uid }]
          }
        ]
      end

      it 'schedules the worker to add members' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user.id], 'add')

        service.execute
      end

      it 'returns success' do
        allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)

        result = service.execute

        expect(result).to be_success
      end

      context 'with case-insensitive operation' do
        let(:operations) do
          [
            {
              op: 'ADD',
              path: 'MEMBERS',
              value: [{ value: identity.extern_uid }]
            }
          ]
        end

        it 'schedules the worker correctly' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user.id], 'add')

          service.execute
        end
      end

      context 'with non-existent user identity' do
        let(:operations) do
          [
            {
              op: 'Add',
              path: 'members',
              value: [{ value: 'non-existent' }]
            }
          ]
        end

        it 'does not schedule the worker' do
          expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

          service.execute
        end
      end

      context 'with externalId operation' do
        let(:operations) do
          [
            {
              op: 'Add',
              path: 'externalId',
              value: 'new-external-id'
            }
          ]
        end

        it 'does not schedule the worker' do
          expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

          service.execute
        end

        it 'returns success' do
          result = service.execute

          expect(result).to be_success
        end
      end
    end

    context 'with remove operation' do
      let_it_be(:user) { create(:user) }
      let_it_be(:identity) { create(:scim_identity, user: user, group: nil) }
      let(:operations) do
        [
          {
            op: 'Remove',
            path: 'members',
            value: [{ value: identity.extern_uid }]
          }
        ]
      end

      it 'schedules the worker to remove members' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user.id], 'remove')

        service.execute
      end

      it 'returns success' do
        allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)

        result = service.execute

        expect(result).to be_success
      end
    end

    context 'with multiple operations' do
      let_it_be(:user1) { create(:user) }
      let_it_be(:user2) { create(:user) }
      let_it_be(:identity1) { create(:scim_identity, user: user1, group: nil) }
      let_it_be(:identity2) { create(:scim_identity, user: user2, group: nil) }
      let(:operations) do
        [
          {
            op: 'Add',
            path: 'members',
            value: [{ value: identity1.extern_uid }]
          },
          {
            op: 'Remove',
            path: 'members',
            value: [{ value: identity2.extern_uid }]
          }
        ]
      end

      it 'schedules workers for each operation' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user1.id], 'add')
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user2.id], 'remove')

        service.execute
      end
    end

    context 'with empty or invalid values' do
      let(:operations) do
        [
          {
            op: 'Add',
            path: 'members',
            value: []
          }
        ]
      end

      it 'does not schedule the worker' do
        expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

        service.execute
      end
    end
  end
end
