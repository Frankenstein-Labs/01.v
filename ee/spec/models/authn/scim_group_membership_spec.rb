# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::ScimGroupMembership, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:user).optional(false) }
  end

  describe 'validations' do
    subject { build(:scim_group_membership) }

    it { is_expected.to validate_presence_of(:scim_group_uid) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(:scim_group_uid) }
  end

  describe 'scopes' do
    let_it_be(:scim_group_uid) { SecureRandom.uuid }
    let_it_be(:another_scim_group_uid) { SecureRandom.uuid }
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }

    let_it_be(:membership1) { create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid) }
    let_it_be(:membership2) { create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid) }
    let_it_be(:membership3) { create(:scim_group_membership, user: user1, scim_group_uid: another_scim_group_uid) }

    describe '.by_scim_group_uid' do
      it 'returns memberships for the specified SCIM group' do
        result = described_class.by_scim_group_uid(scim_group_uid)

        expect(result).to contain_exactly(membership1, membership2)
      end
    end

    describe '.by_user_id' do
      it 'returns memberships for the specified user' do
        result = described_class.by_user_id(user1.id)

        expect(result).to contain_exactly(membership1, membership3)
      end
    end

    describe '.excluding_scim_group_uid' do
      it 'returns memberships excluding the specified SCIM group' do
        result = described_class.excluding_scim_group_uid(scim_group_uid)

        expect(result).to contain_exactly(membership3)
      end
    end
  end

  describe 'class methods' do
    let(:scim_group_uid) { SecureRandom.uuid }

    describe '.user_ids_to_remove_for_replace' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }

      before do
        create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid)
        create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid)
      end

      it 'returns subquery for user IDs that are in the SCIM group but not in target list' do
        target_user_ids = [user2.id, user3.id]
        result = described_class.user_ids_to_remove_for_replace(scim_group_uid, target_user_ids)

        expect(result).to be_a(ActiveRecord::Relation)
        expect(result.to_a.map(&:user_id)).to match_array([user1.id])
      end
    end

    describe '.members_by_scim_group_uid' do
      let_it_be(:another_scim_group_uid) { SecureRandom.uuid }
      let_it_be(:user1) { create(:user, name: 'Alice Example') }
      let_it_be(:user2) { create(:user, name: 'Bob Example') }

      let_it_be(:identity1) { create(:scim_identity, user: user1, group: nil, extern_uid: 'extern-1') }
      let_it_be(:identity2) { create(:scim_identity, user: user2, group: nil, extern_uid: 'extern-2') }

      before do
        create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid)
        create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid)
        create(:scim_group_membership, user: user1, scim_group_uid: another_scim_group_uid)
      end

      it 'returns rows joining each membership to its instance SCIM identity and user' do
        rows = described_class.members_by_scim_group_uid([scim_group_uid, another_scim_group_uid])

        expect(rows.map { |r| [r.scim_group_uid, r.member_extern_uid, r.member_name] }).to match_array([
          [scim_group_uid, 'extern-1', 'Alice Example'],
          [scim_group_uid, 'extern-2', 'Bob Example'],
          [another_scim_group_uid, 'extern-1', 'Alice Example']
        ])
      end

      it 'returns an empty relation for blank input' do
        expect(described_class.members_by_scim_group_uid([])).to be_empty
        expect(described_class.members_by_scim_group_uid(nil)).to be_empty
      end

      it 'excludes users without an instance-level SCIM identity' do
        group_scope = create(:group)
        user_without_instance_identity = create(:user)
        create(:scim_identity, user: user_without_instance_identity, group: group_scope, extern_uid: 'group-scoped')
        create(:scim_group_membership, user: user_without_instance_identity, scim_group_uid: scim_group_uid)

        rows = described_class.members_by_scim_group_uid([scim_group_uid])

        expect(rows.map(&:member_extern_uid)).to match_array(%w[extern-1 extern-2])
      end

      it 'fetches all groups in a single query (no N+1)' do
        control = ActiveRecord::QueryRecorder.new do
          described_class.members_by_scim_group_uid([scim_group_uid]).to_a
        end

        expect do
          described_class.members_by_scim_group_uid([scim_group_uid, another_scim_group_uid]).to_a
        end.not_to exceed_query_limit(control)
      end
    end
  end
end
