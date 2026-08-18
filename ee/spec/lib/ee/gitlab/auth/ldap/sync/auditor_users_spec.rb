# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Auth::Ldap::Sync::AuditorUsers, feature_category: :system_access do
  include LdapHelpers

  let(:adapter) { ldap_adapter }

  describe '#update_permissions' do
    let_it_be(:user) { create(:user) }
    let_it_be(:auditor) { create(:auditor) }
    let_it_be(:audit_group) { ldap_group_entry(user_dn(user.username), cn: 'audit_group') }

    let(:sync_auditor) { described_class.new(proxy(adapter)) }

    before do
      stub_ldap_config(audit_group: 'audit_group', active_directory: false)
      stub_ldap_group_find_by_cn('audit_group', audit_group, adapter)
    end

    it 'adds user as auditor' do
      create(:identity, user: user, extern_uid: user_dn(user.username))

      expect { sync_auditor.update_permissions }
        .to change { user.reload.auditor? }.from(false).to(true)
    end

    it 'removes users that are not in the LDAP group' do
      create(:identity, user: auditor, extern_uid: user_dn(auditor.username))

      expect { sync_auditor.update_permissions }
        .to change { auditor.reload.auditor? }.from(true).to(false)
    end

    it 'leaves auditor users that do not have the LDAP provider' do
      expect { sync_auditor.update_permissions }
        .not_to change { auditor.reload.auditor? }
    end

    context 'when auditor users have a different provider identity' do
      before do
        create(:identity,
          user: auditor,
          provider: 'ldapsecondary',
          extern_uid: user_dn(auditor.username))
      end

      it 'leaves them' do
        expect { sync_auditor.update_permissions }
          .not_to change { auditor.reload.auditor? }
      end
    end

    context 'when ldap connection fails' do
      before do
        unstub_ldap_group_find_by_cn
        raise_ldap_connection_error
      end

      it 'logs a debug message' do
        expect(Gitlab::AppLogger)
          .to receive(:warn)
                .with("Error syncing auditor users for provider 'ldapmain'. LDAP connection Error")
                .at_least(:once)

        sync_auditor.update_permissions
      end
    end
  end
end
