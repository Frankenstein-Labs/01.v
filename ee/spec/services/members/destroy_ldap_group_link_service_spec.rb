# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::DestroyLdapGroupLinkService, feature_category: :system_access do
  describe '.execute' do
    context 'with a plain link' do
      let_it_be(:group) { create(:group) }
      let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }

      subject(:execute) { described_class.execute(ldap_group_link) }

      it 'destroys the ldap group link' do
        expect { execute }.to change { group.ldap_group_links.count }.by(-1)
      end

      it 'locks the group row for the duration of the destroy and orphan check' do
        expect(group).to receive(:with_lock).and_call_original

        execute
      end
    end

    context 'when it was the last link for that provider' do
      let_it_be(:group) { create(:group) }
      let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }
      let_it_be(:member_user) { create(:user) }
      let_it_be_with_reload(:orphaned_member) do
        create(:group_member, :developer, group: group, user: member_user, ldap: true)
      end

      let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

      subject(:execute) { described_class.execute(ldap_group_link) }

      it 'resets the ldap flag for members orphaned by the removal' do
        expect { execute }.to change { orphaned_member.reload.ldap? }.from(true).to(false)
      end
    end

    context 'when it was the last link for that provider, checking lock scope' do
      let_it_be(:group) { create(:group) }
      let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }

      subject(:execute) { described_class.execute(ldap_group_link) }

      it 'resets the ldap flag after the group lock is released, not inside it' do
        locked = false

        allow(group).to receive(:with_lock).and_wrap_original do |method, *args, &block|
          locked = true
          result = method.call(*args, &block)
          locked = false
          result
        end

        expect(Members::ResetOrphanedLdapProviderFlagsService).to receive(:execute) do
          expect(locked).to be(false)
        end

        execute
      end
    end

    context 'when other links remain for that provider' do
      let_it_be(:group) { create(:group) }
      let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }
      let_it_be(:other_ldap_group_link) do
        create(:ldap_group_link, group: group, cn: 'other-group', provider: 'ldapmain')
      end

      let_it_be(:member_user) { create(:user) }
      let_it_be_with_reload(:remaining_member) do
        create(:group_member, :developer, group: group, user: member_user, ldap: true)
      end

      let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

      subject(:execute) { described_class.execute(ldap_group_link) }

      it 'does not reset the ldap flag' do
        expect { execute }.not_to change { remaining_member.reload.ldap? }
      end
    end

    context 'when the link has no provider column value set' do
      let_it_be(:group) { create(:group) }
      let_it_be(:null_provider_link) { create(:ldap_group_link, group: group, provider: nil) }
      let_it_be(:member_user) { create(:user) }
      let_it_be_with_reload(:orphaned_member) do
        create(:group_member, :developer, group: group, user: member_user, ldap: true)
      end

      let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

      subject(:execute) { described_class.execute(null_provider_link) }

      it 'resets the ldap flag using the fallback provider' do
        expect { execute }.to change { orphaned_member.reload.ldap? }.from(true).to(false)
      end
    end

    context 'when the provider is no longer configured' do
      let_it_be(:group) { create(:group) }
      let_it_be(:member_user) { create(:user) }
      let_it_be_with_reload(:member) { create(:group_member, :developer, group: group, user: member_user, ldap: true) }
      let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldap-decommissioned') }

      let(:decommissioned_link) do
        create(:ldap_group_link, group: group, cn: 'decommissioned-group', provider: 'ldap-decommissioned')
      end

      before do
        decommissioned_link
      end

      subject(:execute) { described_class.execute(decommissioned_link) }

      it 'does not reset the ldap flag' do
        expect { execute }.not_to change { member.reload.ldap? }
      end

      it 'still destroys the link' do
        expect { execute }.to change { group.ldap_group_links.count }.by(-1)
      end
    end
  end
end
