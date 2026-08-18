# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupMemberPolicy, feature_category: :system_access do
  include PolicyHelpers

  let_it_be(:owner) { create(:user) }

  before do
    allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
    stub_licensed_features(ldap_group_sync: true)
  end

  context 'when the group is actively ldap_synced' do
    let_it_be(:group) { create(:group, owners: owner) }
    let_it_be(:ldap_group_link) { create(:ldap_group_link, group: group, cn: 'devs', group_access: Gitlab::Access::DEVELOPER) }
    let_it_be(:member_user) { create(:user) }
    let_it_be_with_reload(:member) { create(:group_member, :developer, group: group, user: member_user, ldap: true) }

    subject { described_class.new(owner, member) }

    it 'confirms the group is genuinely ldap_synced' do
      expect(group.ldap_synced?).to be true
    end

    context 'and the member is not overridden' do
      it 'prevents update_group_member' do
        expect_disallowed(:update_group_member)
      end
    end

    context 'and the member is overridden' do
      before do
        member.update!(override: true)
      end

      it 'allows update_group_member' do
        expect_allowed(:update_group_member)
      end
    end
  end

  context 'when the group is no longer ldap_synced (last link removed)' do
    let_it_be(:group) { create(:group, owners: owner) }
    let_it_be(:member_user) { create(:user) }
    let_it_be_with_reload(:member) { create(:group_member, :developer, group: group, user: member_user, ldap: true) }

    before do
      link = create(:ldap_group_link, group: group, cn: 'devs', group_access: Gitlab::Access::DEVELOPER)
      link.destroy!
    end

    subject { described_class.new(owner, member.reload) }

    it 'confirms the group is genuinely no longer ldap_synced' do
      expect(group.reload.ldap_synced?).to be false
    end

    it 'allows update_group_member even though the stale ldap flag is still true and override is false' do
      expect(member.ldap?).to be true
      expect(member.override?).to be false

      expect_allowed(:update_group_member)
    end
  end

  context 'when the member is not ldap-managed at all' do
    let_it_be(:group) { create(:group, owners: owner) }
    let_it_be(:plain_member) { create(:group_member, :developer, group: group, ldap: false) }

    subject { described_class.new(owner, plain_member) }

    it 'allows update_group_member' do
      expect_allowed(:update_group_member)
    end
  end
end
