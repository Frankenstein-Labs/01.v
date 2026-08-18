# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Ldap::AdminRolesSyncService, feature_category: :permissions do
  describe '.enqueue_sync' do
    subject(:enqueue_sync) { described_class.enqueue_sync }

    before do
      allow(::Gitlab::Auth::Ldap::Config).to receive_messages(providers: ['ldap'])
    end

    it 'enqueues the LdapAdminRoleWorker' do
      expect(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      enqueue_sync
    end

    context 'with sync statuses' do
      let_it_be(:invalid_provider_sync) do
        create(:ldap_admin_role_link, :skip_validate, cn: 'group1', sync_status: 'never_synced',
          provider: 'doesnotexist')
      end

      let_it_be(:ready_sync) do
        create(:ldap_admin_role_link, :skip_validate, cn: 'group1', sync_status: 'never_synced', provider: 'ldap')
      end

      let_it_be(:running_sync) do
        create(:ldap_admin_role_link, :skip_validate, cn: 'group2', sync_status: 'running', provider: 'ldap')
      end

      let_it_be(:successful_sync) do
        create(:ldap_admin_role_link, :skip_validate, cn: 'group3', sync_status: 'successful', provider: 'ldap')
      end

      let_it_be(:failed_sync) do
        create(:ldap_admin_role_link, :skip_validate, cn: 'group4', sync_status: 'failed', provider: 'ldap')
      end

      it 'marks syncs that are not running as queued and invalid syncs as failed', :aggregate_failures do
        enqueue_sync

        expect(invalid_provider_sync.reload.sync_status).to eq('failed')
        expect(invalid_provider_sync.sync_started_at).not_to be_nil
        expect(invalid_provider_sync.sync_ended_at).not_to be_nil
        expect(invalid_provider_sync.sync_error).to eq('Provider is invalid')

        expect(ready_sync.reload.sync_status).to eq('queued')
        expect(running_sync.reload.sync_status).to eq('running')
        expect(successful_sync.reload.sync_status).to eq('queued')
        expect(failed_sync.reload.sync_status).to eq('queued')
      end
    end

    it 'does not raise an error when the worker is enqueued' do
      allow(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      expect { enqueue_sync }.not_to raise_error
    end
  end
end
