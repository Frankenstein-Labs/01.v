# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::Member, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:parent_groups) { [] }
  let_it_be(:group_member) { create(:group_member, :developer, group: group) }
  let_it_be(:invited_member) { create(:group_member, :invited, :maintainer, group: group) }

  describe 'initialization' do
    it 'creates a new instance correctly' do
      member = described_class.new(group_member, group, parent_groups)

      aggregate_failures do
        expect(member.id).to eq(group_member.id)
        expect(member.name).to eq(group_member.user.name)
        expect(member.username).to eq(group_member.user.username)
        expect(member.email).to eq(group_member.user.email)
        expect(member.membershipable_id).to eq(group.id)
        expect(member.membershipable_path).to eq(group.full_path)
        expect(member.membershipable_name).to eq(group.name)
        expect(member.membershipable_class).to eq(group.class.name)
        expect(member.membershipable_type).to eq('Group')
        expect(member.role).to eq('Developer')
        expect(member.role_type).to eq('default')
        expect(member.membership_type).to eq('direct')
        expect(member.membership_status).to eq('approved')
        expect(member.membership_source).to eq(group.full_path)
        expect(member.access_granted).to eq(group_member.created_at.iso8601)
        expect(member.access_expiration).to eq(group_member.expires_at)
        expect(member.access_level).to eq(group_member.access_level)
        expect(member.last_activity).to eq(group_member.user.last_activity_on)
        expect { member.unknown }.to raise_error(NoMethodError)
      end
    end

    it 'creates a new instance correctly for a pending invite member' do
      member = described_class.new(invited_member, group, parent_groups)

      aggregate_failures do
        expect(member.id).to eq(invited_member.id)
        expect(member.name).to be_nil
        expect(member.username).to be_nil
        expect(member.email).to eq(invited_member.invite_email)
        expect(member.membershipable_id).to eq(group.id)
        expect(member.membershipable_path).to eq(group.full_path)
        expect(member.membershipable_name).to eq(group.name)
        expect(member.membershipable_class).to eq(group.class.name)
        expect(member.membershipable_type).to eq('Group')
        expect(member.role).to eq('Maintainer')
        expect(member.role_type).to eq('default')
        expect(member.membership_type).to eq('direct')
        expect(member.membership_status).to eq('pending')
        expect(member.membership_source).to eq(group.full_path)
        expect(member.access_granted).to eq(invited_member.created_at.iso8601)
        expect(member.access_expiration).to eq(invited_member.expires_at)
        expect(member.access_level).to eq(invited_member.access_level)
        expect(member.last_activity).to be_nil
        expect { member.unknown }.to raise_error(NoMethodError)
      end
    end
  end
end
