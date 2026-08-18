# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ResetOrphanedLdapProviderFlagsService, feature_category: :system_access do
  describe '.execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:member_user) { create(:user) }
    let_it_be(:member) { create(:group_member, :developer, group: group, user: member_user, ldap: true) }
    let_it_be(:identity) { create(:identity, user: member_user, provider: 'ldapmain') }

    subject(:execute) { described_class.execute(group, providers) }

    context 'when the provider has no remaining links for the group' do
      let(:providers) { ['ldapmain'] }

      it 'resets the ldap flag for members whose access came from that provider' do
        expect { execute }.to change { member.reload.ldap? }.from(true).to(false)
      end

      it 'does not destroy the membership' do
        expect { execute }.not_to change { group.members.count }
      end

      it 'does not change the member access level' do
        expect { execute }.not_to change { member.reload.access_level }
      end

      it 'does not touch a member with a different provider identity' do
        other_user = create(:user)
        other_member = create(:group_member, :developer, group: group, user: other_user, ldap: true)
        create(:identity, user: other_user, provider: 'ldapsecondary')

        execute

        expect(other_member.reload.ldap?).to be true
      end

      it 'does not touch a member that is already ldap: false' do
        non_ldap_user = create(:user)
        non_ldap_member = create(:group_member, :developer, group: group, user: non_ldap_user, ldap: false)
        create(:identity, user: non_ldap_user, provider: 'ldapmain')

        expect { execute }.not_to change { non_ldap_member.reload.updated_at }
      end
    end

    context 'when the provider still has other links for the group' do
      let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }
      let(:providers) { ['ldapmain'] }

      it 'does not reset the ldap flag' do
        expect { execute }.not_to change { member.reload.ldap? }
      end
    end

    context 'when the provider is no longer configured' do
      let(:providers) { ['ldap-decommissioned'] }

      it 'does not reset the ldap flag' do
        expect { execute }.not_to change { member.reload.ldap? }
      end
    end

    context 'with multiple providers' do
      let_it_be(:remaining_link) { create(:ldap_group_link, group: group, provider: 'ldapmain') }
      let(:providers) { %w[ldapmain ldap-decommissioned ldapother] }

      it 'only resets the flag for orphaned, still-configured providers' do
        other_user = create(:user)
        other_member = create(:group_member, :developer, group: group, user: other_user, ldap: true)
        create(:identity, user: other_user, provider: 'ldapother')

        allow(Gitlab::Auth::Ldap::Config).to receive(:providers).and_return(%w[ldapmain ldapother])

        execute

        expect(member.reload.ldap?).to be true
        expect(other_member.reload.ldap?).to be false
      end
    end
  end
end
