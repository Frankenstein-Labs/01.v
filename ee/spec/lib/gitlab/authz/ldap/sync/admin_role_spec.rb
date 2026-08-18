# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Authz::Ldap::Sync::AdminRole, feature_category: :permissions do
  include LdapHelpers

  let_it_be_with_reload(:adapter) { ldap_adapter }
  let_it_be(:provider) { 'ldapmain' }
  # `freeze: false` is required here: this `let_it_be` subject is mutated
  # in-memory across examples in a way that survives both
  # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
  # association/collection or a non-persisted attribute). Keeping it unfrozen
  # is the only correct cure (see gitlab-org/gitlab#602925).
  let_it_be(:ldap_proxy, freeze: false) { proxy(adapter, provider) }

  let_it_be_with_reload(:user) { create(:user) }

  let_it_be(:admin_role) { create(:member_role, :admin, name: 'Admin role') }
  let_it_be(:admin_role_2) { create(:member_role, :admin, name: 'Admin role 2') }

  before do
    allow(Gitlab.config.ldap).to receive_messages(enabled: true)

    create(:identity, user: user, extern_uid: user_dn(user.username))

    stub_ldap_config(active_directory: false)

    stub_licensed_features(custom_roles: true)
  end

  describe '.execute_all_providers' do
    subject(:execute_all_providers) { described_class.execute_all_providers }

    before do
      allow(::Gitlab::Auth::Ldap::Config).to receive(:providers).and_return(%w[ldapmain ldapalt])
    end

    it 'calls the execute method for all providers' do
      admin_role_syncer = instance_double(described_class)

      expect(described_class).to receive(:new).twice.and_return(admin_role_syncer)
      expect(admin_role_syncer).to receive(:execute).twice

      execute_all_providers
    end
  end

  describe '#execute' do
    subject(:sync_admin_roles) { described_class.new(provider).execute }

    shared_examples 'syncing admin roles' do
      context 'with all functionality against one LDAP group type' do
        context 'with sync statuses' do
          let(:member_dn) { user_dn(user.username) }

          it 'marks the sync as successful', :freeze_time do
            sync_admin_roles

            admin_role_link.reload

            expect(admin_role_link.sync_status).to eq('successful')
            expect(admin_role_link.sync_ended_at).to eq(DateTime.current)
            expect(admin_role_link.last_successful_sync_at).to eq(DateTime.current)
          end

          context 'when the ldap sync has already started' do
            before do
              admin_role_link.running!
            end

            it 'logs a warning message' do
              expect(::Gitlab::AppLogger).to receive(:warn).with(
                message: 'LDAP admin role sync is already running.',
                provider: provider
              )

              sync_admin_roles
            end

            it 'does not assign admin roles' do
              sync_admin_roles

              expect(assigned_admin_role(user)).to be_nil
            end
          end

          context 'when ldap connection fails' do
            before do
              unstub_ldap_group_find_by_cn
              unstub_ldap_filter
              raise_ldap_connection_error
            end

            it 'marks the sync as failed', :freeze_time do
              sync_admin_roles

              admin_role_link.reload

              expect(admin_role_link.sync_status).to eq('failed')
              expect(admin_role_link.sync_ended_at).to eq(DateTime.current)
              expect(admin_role_link.sync_error).to eq('Gitlab::Auth::Ldap::LdapConnectionError')
            end

            it 'logs an error message' do
              expect(::Gitlab::AppLogger).to receive(:error).with(
                message: 'Error during LDAP admin role sync for provider.',
                provider: provider
              )

              sync_admin_roles
            end
          end

          context 'when custom_roles licensed feature is unavailable' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            it 'logs a warning message' do
              expect(::Gitlab::AppLogger).to receive(:warn).with(
                message: 'LDAP admin role sync is not enabled.',
                provider: provider
              )

              sync_admin_roles
            end

            it 'does not assign admin roles' do
              sync_admin_roles

              expect(assigned_admin_role(user)).to be_nil
            end
          end
        end

        context 'with basic add/update actions' do
          let(:member_dn) { user_dn(user.username) }

          context 'when new user is added to the LDAP group' do
            it 'assigns admin role and sets ldap attribute to true' do
              sync_admin_roles

              expect(assigned_admin_role(user).member_role).to eq(admin_role)
              expect(assigned_admin_role(user).ldap).to be_truthy
            end
          end

          it 'updates admin role' do
            create(:admin_member_role, user: user, member_role: admin_role_2, ldap: true)

            sync_admin_roles

            expect(assigned_admin_role(user).member_role).to eq(admin_role)
            expect(assigned_admin_role(user).ldap).to be_truthy
          end

          context 'when the user already has an admin role assigned not from LDAP' do
            before do
              create(:admin_member_role, user: user, member_role: admin_role_2, ldap: false)
            end

            it 'updates admin role' do
              sync_admin_roles

              expect(assigned_admin_role(user).member_role).to eq(admin_role)
              expect(assigned_admin_role(user).ldap).to be_truthy
            end
          end

          context 'when the admin link is deleted' do
            before do
              admin_role_link.destroy!
            end

            it 'unassigns the admin role' do
              sync_admin_roles

              expect(assigned_admin_role(user)).to be_nil
            end
          end
        end

        context 'when existing user is no longer in LDAP group' do
          let(:member_dn) { user_dn('other_user') }

          before do
            create(:admin_member_role, user: user, member_role: admin_role, ldap: true)
          end

          it 'unassigns the admin role' do
            sync_admin_roles

            expect(assigned_admin_role(user)).to be_nil
          end
        end

        context 'when the user is an admin' do
          let_it_be(:admin) { create(:admin) }
          let(:member_dn) { user_dn(admin.username) }

          it 'does not assign an admin role' do
            sync_admin_roles

            expect(assigned_admin_role(admin)).to be_nil
          end
        end

        context 'when saving a record fails' do
          let(:member_dn) { user_dn(user.username) }

          before do
            allow_next_instance_of(Users::UserMemberRole) do |record|
              errors = ActiveModel::Errors.new(record)
              errors.add(:base, 'Test error')

              allow(record).to receive_messages(valid?: false, errors: errors)
            end
          end

          it 'logs an error message' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Failed to assign admin role to user',
              admin_role_name: admin_role.name,
              username: user.username,
              error_message: 'Test error'
            )

            sync_admin_roles
          end
        end
      end
    end

    context 'when syncing by cn (LDAP group)' do
      let_it_be_with_reload(:admin_role_link) do
        create(:ldap_admin_role_link, :skip_validate, member_role: admin_role, cn: 'ldap_group1')
      end

      let(:ldap_group1) { ldap_group_entry(member_dn) }

      before do
        stub_ldap_group_find_by_cn('ldap_group1', ldap_group1, adapter)
      end

      it_behaves_like 'syncing admin roles'

      context 'when the user belongs to multiple LDAP groups' do
        # We have 2 LDAP groups, both are assigned a different admin custom role

        let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }
        let(:ldap_group2) { ldap_group_entry(user_dn(user.username)) }

        let_it_be(:admin_role_link_2) do
          create(:ldap_admin_role_link, :skip_validate, member_role: admin_role_2, cn: 'ldap_group2')
        end

        before do
          stub_ldap_group_find_by_cn('ldap_group2', ldap_group2, adapter)
        end

        it 'assign the admin role of the oldest created link' do
          sync_admin_roles

          expect(assigned_admin_role(user).member_role).to eq(admin_role)
          expect(assigned_admin_role(user).ldap).to be_truthy
        end

        context 'when the user already has a different admin role' do
          before do
            create(:admin_member_role, user: user, member_role: admin_role_2, ldap: true)
          end

          it 're-assigns the admin role of the oldest created link' do
            sync_admin_roles

            expect(assigned_admin_role(user).member_role).to eq(admin_role)
            expect(assigned_admin_role(user).ldap).to be_truthy
          end
        end
      end
    end

    context 'when syncing by filter' do
      let_it_be_with_reload(:admin_role_link) do
        create(:ldap_admin_role_link, :skip_validate, member_role: admin_role, filter: '(a=b)', cn: nil)
      end

      before do
        allow(Gitlab::Auth::Ldap::Adapter).to receive(:new).with(provider).and_return(adapter)
        allow(EE::Gitlab::Auth::Ldap::Sync::Proxy).to receive(:new).with(provider, adapter).and_return(ldap_proxy)

        allow(ldap_proxy).to receive(:dns_for_filter).with('(a=b)').and_return([member_dn])
      end

      it_behaves_like 'syncing admin roles'

      context 'when the user belongs to multiple filters' do
        let(:member_dn) { user_dn(user.username) }

        let_it_be_with_reload(:admin_role_link_2) do
          create(:ldap_admin_role_link, :skip_validate, member_role: admin_role_2, filter: '(x=y)', cn: nil)
        end

        before do
          allow(ldap_proxy).to receive(:dns_for_filter).with('(x=y)').and_return([member_dn])
        end

        it 'assign the admin role of the oldest created link' do
          sync_admin_roles

          expect(assigned_admin_role(user).member_role).to eq(admin_role)
          expect(assigned_admin_role(user).ldap).to be_truthy
        end

        context 'when the user already has a different admin role' do
          before do
            create(:admin_member_role, user: user, member_role: admin_role_2, ldap: true)
          end

          it 're-assigns the admin role of the oldest created link' do
            sync_admin_roles

            expect(assigned_admin_role(user).member_role).to eq(admin_role)
            expect(assigned_admin_role(user).ldap).to be_truthy
          end
        end
      end
    end

    context 'when syncing by both cn and filter' do
      let_it_be(:user_1) { create(:user) }
      let_it_be(:user_2) { create(:user) }

      # user_3 belongs to both cn & filter
      let_it_be(:user_3) { create(:user) }

      let(:user_1_dn) { user_dn(user_1.username) }
      let(:user_2_dn) { user_dn(user_2.username) }
      let(:user_3_dn) { user_dn(user_3.username) }

      let_it_be_with_reload(:admin_role_link) do
        create(:ldap_admin_role_link, :skip_validate, member_role: admin_role, cn: 'ldap_group1')
      end

      let_it_be_with_reload(:admin_role_link_2) do
        create(:ldap_admin_role_link, :skip_validate, member_role: admin_role_2, filter: '(a=b)', cn: nil)
      end

      let(:ldap_group1) do
        ldap_group_entry(%W[#{user_1_dn} #{user_3_dn}])
      end

      before do
        # LDAP identities
        create(:identity, user: user_1, extern_uid: user_1_dn)
        create(:identity, user: user_2, extern_uid: user_2_dn)
        create(:identity, user: user_3, extern_uid: user_3_dn)

        # for cn
        stub_ldap_group_find_by_cn('ldap_group1', ldap_group1, adapter)

        # for filter
        allow(Gitlab::Auth::Ldap::Adapter).to receive(:new).with(provider).and_return(adapter)
        allow(EE::Gitlab::Auth::Ldap::Sync::Proxy).to receive(:new).with(provider, adapter).and_return(ldap_proxy)

        allow(ldap_proxy).to receive(:dns_for_filter).with('(a=b)').and_return([user_2_dn, user_3_dn])
      end

      it 'assigns the correct admin role' do
        sync_admin_roles

        expect(assigned_admin_role(user_1).member_role).to eq(admin_role)
        expect(assigned_admin_role(user_1).ldap).to be_truthy

        expect(assigned_admin_role(user_2).member_role).to eq(admin_role_2)
        expect(assigned_admin_role(user_2).ldap).to be_truthy

        expect(assigned_admin_role(user_3).member_role).to eq(admin_role)
        expect(assigned_admin_role(user_3).ldap).to be_truthy
      end
    end

    context 'when syncing multiple providers' do
      let(:ldap_group1) { ldap_group_entry(user_dn(user.username)) }
      let(:ldap_group2) { ldap_group_entry(user_dn(user.username)) }

      let(:ldapmain_adapter) { ldap_adapter('ldapmain') }
      let(:ldapalt_adapter) { ldap_adapter('ldapalt') }

      before do
        allow(::Gitlab::Auth::Ldap::Config).to receive(:providers).and_return(%w[ldapmain ldapalt])

        stub_provider(ldapmain_adapter, 'ldapmain')
        stub_provider(ldapalt_adapter, 'ldapalt')

        stub_ldap_group_find_by_cn('ldap_group1', ldap_group1, ldapmain_adapter)
      end

      context 'when user has multiple identities' do
        before do
          create(:ldap_admin_role_link, :skip_validate, member_role: admin_role, cn: 'ldap_group1')

          create(:identity, user: user, extern_uid: user_dn(user.username), provider: 'ldapalt')
        end

        it 'does not change the admin role' do
          described_class.execute_all_providers

          expect(assigned_admin_role(user).member_role).to eq(admin_role)
        end
      end
    end
  end

  def assigned_admin_role(user)
    user.reload.user_member_role
  end

  def unstub_ldap_filter
    allow(ldap_proxy).to receive(:dns_for_filter).and_call_original
  end

  def stub_provider(adapter, provider)
    proxy = proxy(adapter, provider)

    allow(Gitlab::Auth::Ldap::Adapter).to receive(:new).and_return(adapter)
    allow(EE::Gitlab::Auth::Ldap::Sync::Proxy).to receive(:open).and_yield(proxy)
  end
end
