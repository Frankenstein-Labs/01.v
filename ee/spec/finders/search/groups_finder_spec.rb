# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupsFinder, feature_category: :global_search do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let(:params) { {} }

    subject(:execute) { described_class.new(user: user, params: params).execute }

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has no matching groups' do
      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when features and min_access_level are both provided' do
      let(:params) { { features: [:foo], min_access_level: ::Gitlab::Access::GUEST } }

      it 'raises an exception' do
        expect { execute }.to raise_error(ArgumentError)
      end
    end

    context 'when user has direct membership with default role' do
      it 'returns that group' do
        group.add_developer(user)

        expect(execute).to contain_exactly(group)
      end

      context 'when features is provided' do
        context 'and user does not have access level required for feature' do
          let(:params) { { features: [:repository] } }

          it 'returns nothing' do
            group.add_guest(user)

            expect(execute).to be_empty
          end
        end

        context 'and user has access level required for feature' do
          let(:params) { { features: [:repository] } }

          it 'returns that group' do
            group.add_developer(user)

            expect(execute).to contain_exactly(group)
          end
        end
      end

      context 'when min_access_level higher than GUEST is provided' do
        let(:params) { { min_access_level: ::Gitlab::Access::OWNER } }

        it 'returns nothing' do
          group.add_guest(user)

          expect(execute).to be_empty
        end
      end
    end

    context 'when user has direct membership with custom role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let(:params) { { features: [:repository] } }

      context 'and user has custom role without the ability' do
        it 'returns nothing' do
          admin_runners_role = create(:member_role, :guest, :admin_runners, namespace: group, read_code: false)
          create(:group_member, :guest, member_role: admin_runners_role, user: user, source: group)

          expect(execute).to be_empty
        end
      end

      context 'and user has custom role with the ability' do
        it 'returns that group' do
          read_code_role = create(:member_role, :guest, :read_code, namespace: group)
          create(:group_member, :guest, member_role: read_code_role, user: user, source: group)

          expect(execute).to contain_exactly(group)
        end
      end
    end

    context 'when user has membership through a shared group link with default role' do
      let_it_be_with_reload(:shared_with_group) { create(:group) }
      let_it_be_with_reload(:group_group_link) do
        create(
          :group_group_link,
          group_access: ::Gitlab::Access::GUEST,
          shared_group: group,
          shared_with_group: shared_with_group
        )
      end

      it 'returns the direct access group and the shared group' do
        shared_with_group.add_developer(user)

        expect(execute).to contain_exactly(shared_with_group, group)
      end

      context 'and the group link is expired' do
        it 'returns only the direct access group' do
          shared_with_group.add_developer(user)
          group_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end

      context 'and user does not have min_access_level required' do
        let(:params) { { min_access_level: ::Gitlab::Access::OWNER } }

        it 'returns nothing' do
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user does not have access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns nothing' do
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user has access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns the direct access group and the shared group' do
          group_group_link.update!(group_access: ::Gitlab::Access::DEVELOPER)
          shared_with_group.add_developer(user)

          expect(execute).to contain_exactly(shared_with_group, group)
        end
      end
    end

    context 'when user has membership through a shared group link with custom role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let_it_be_with_reload(:member_role) do
        create(:member_role, :guest, :admin_runners, namespace: group, read_code: false)
      end

      let_it_be_with_reload(:shared_with_group) { create(:group) }
      let_it_be_with_reload(:group_group_link) do
        create(:group_group_link, group_access: ::Gitlab::Access::GUEST,
          member_role: member_role, shared_with_group: shared_with_group, shared_group: group)
      end

      it 'returns the direct access group and the shared group' do
        shared_with_group.add_developer(user)

        expect(execute).to contain_exactly(shared_with_group, group)
      end

      context 'and the group link is expired' do
        it 'returns only the direct access group' do
          shared_with_group.add_developer(user)
          group_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end

      context 'and user does not have access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns nothing' do
          member_role.update!(read_code: false)
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user has access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns the direct access group and the shared group' do
          member_role.update!(read_code: true)
          shared_with_group.add_developer(user)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end
    end

    it 'enforces REDIS_CACHE_TTL is shorter than CACHE_VERSION_TTL' do
      expect(described_class::REDIS_CACHE_TTL).to be < described_class::CACHE_VERSION_TTL
    end

    describe 'Redis caching' do
      let_it_be(:group1) { create(:group) }
      let_it_be(:group2) { create(:group) }

      before_all do
        group1.add_developer(user)
        group2.add_developer(user)
      end

      before do
        allow(described_class).to receive(:cache_version).and_return('testver')
      end

      it 'caches the result in Redis' do
        cache_key = described_class.redis_cache_key(user.id, min_access_level: 10)
        expect(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Rails.cache).to receive(:write).and_call_original
        expect(Rails.cache).to receive(:write)
          .with(cache_key, match_array([group1.id, group2.id]), expires_in: 5.minutes)

        expect(execute).to contain_exactly(group1, group2)
      end

      it 'uses cached result on subsequent calls' do
        cache_key = described_class.redis_cache_key(user.id, min_access_level: 10)
        cached_ids = [group1.id, group2.id]
        expect(Rails.cache).to receive(:read).with(cache_key).and_return(cached_ids)
        expect(Rails.cache).not_to receive(:write).with(cache_key, anything, anything)

        expect(execute).to contain_exactly(group1, group2)
      end

      context 'with different min_access_level' do
        let(:params) { { min_access_level: ::Gitlab::Access::MAINTAINER } }

        it 'uses different cache key' do
          cache_key = described_class.redis_cache_key(user.id, min_access_level: 40)
          expect(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
          allow(Rails.cache).to receive(:write).and_call_original
          expect(Rails.cache).to receive(:write)
            .with(cache_key, [], expires_in: 5.minutes)

          expect(execute).to be_empty
        end
      end

      context 'when features param is provided' do
        let(:params) { { features: [:repository] } }

        it 'uses a different cache key than an equivalent min_access_level call' do
          features_cache_key = described_class.redis_cache_key(user.id, min_access_level: 20, features: [:repository])
          min_access_cache_key = described_class.redis_cache_key(user.id, min_access_level: 20)

          expect(features_cache_key).not_to eq(min_access_cache_key)
        end

        it 'includes sorted features in the cache key' do
          cache_key = described_class.redis_cache_key(user.id, min_access_level: 20, features: [:repository])
          expect(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
          allow(Rails.cache).to receive(:write).and_call_original
          expect(Rails.cache).to receive(:write).with(cache_key, anything, expires_in: 5.minutes)

          group1.add_developer(user)
          execute
        end

        it 'does not collide with a min_access_level:20 call that skips custom role check' do
          min_access_cache_key = described_class.redis_cache_key(user.id, min_access_level: 20)
          features_cache_key = described_class.redis_cache_key(user.id, min_access_level: 20, features: [:repository])
          cached_ids = [group1.id]

          allow(Rails.cache).to receive(:read).with(min_access_cache_key).and_return(cached_ids)

          expect(Rails.cache).to receive(:read).with(features_cache_key).and_return(nil)
          allow(Rails.cache).to receive(:write).and_call_original
          expect(Rails.cache).to receive(:write).with(features_cache_key, anything, expires_in: 5.minutes)

          described_class.new(user: user, params: params).execute
        end
      end

      context 'when features has multiple values' do
        let(:params) { { features: [:wiki, :repository] } }

        it 'sorts features in the cache key for consistency' do
          cache_key = described_class.redis_cache_key(user.id, min_access_level: 10, features: %i[repository wiki])
          expect(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
          allow(Rails.cache).to receive(:write).and_call_original
          expect(Rails.cache).to receive(:write).with(cache_key, anything, expires_in: 5.minutes)

          execute
        end
      end
    end
  end

  describe '#execute_with_access_levels' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let(:params) { { min_access_level: ::Gitlab::Access::REPORTER } }

    subject(:rows) { described_class.new(user: user, params: params).execute_with_access_levels }

    def access_levels_by_group(result)
      result.to_h { |r| [r[:traversal_ids].last, r[:access_levels]] }
    end

    def rows_by_group(result)
      result.index_by { |r| r[:traversal_ids].last }
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns an empty array' do
        expect(rows).to eq([])
      end
    end

    context 'when features: is provided' do
      let(:params) { { features: [:repository] } }

      it 'raises ArgumentError to keep the authz contract clean' do
        expect { rows }.to raise_error(ArgumentError, /does not support features/)
      end
    end

    context 'when user has a direct membership above the minimum' do
      before_all do
        group.add_developer(user)
      end

      it 'tags the group with the raw Member.access_level' do
        expect(access_levels_by_group(rows)[group.id]).to eq([Gitlab::Access::DEVELOPER])
      end
    end

    context 'when user has subgroup-only membership' do
      let_it_be(:subgroup_only_user) { create(:user) }
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group, reporters: subgroup_only_user) }
      let(:user) { subgroup_only_user }

      it 'returns the subgroup full traversal_ids without returning the parent' do
        result = rows_by_group(rows)

        expect(result[subgroup.id]).to include(
          organization_id: subgroup.organization_id,
          traversal_ids: subgroup.traversal_ids,
          access_levels: [Gitlab::Access::REPORTER]
        )
        expect(subgroup.traversal_ids).to match_array([parent_group.id, subgroup.id])
        expect(result).not_to have_key(parent_group.id)
      end
    end

    context 'when user has access at mixed hierarchy levels' do
      let_it_be(:mixed_hierarchy_user) { create(:user) }
      let_it_be(:top_level_group) { create(:group, reporters: mixed_hierarchy_user) }
      let_it_be(:other_parent_group) { create(:group) }
      let_it_be(:developer_subgroup) { create(:group, parent: other_parent_group, developers: mixed_hierarchy_user) }
      let(:user) { mixed_hierarchy_user }

      it 'returns each group with its own traversal_ids and access_levels' do
        result = rows_by_group(rows)

        expect(result[top_level_group.id]).to include(
          organization_id: top_level_group.organization_id,
          traversal_ids: top_level_group.traversal_ids,
          access_levels: [Gitlab::Access::REPORTER]
        )
        expect(result[developer_subgroup.id]).to include(
          organization_id: developer_subgroup.organization_id,
          traversal_ids: developer_subgroup.traversal_ids,
          access_levels: [Gitlab::Access::DEVELOPER]
        )
        expect(developer_subgroup.traversal_ids).to match_array([other_parent_group.id, developer_subgroup.id])
        expect(result).not_to have_key(other_parent_group.id)
      end
    end

    context 'when user has access via a GroupGroupLink' do
      let_it_be(:shared_group) { create(:group) }
      let_it_be(:shared_with_group) { create(:group) }

      context 'and direct access on the sharer exceeds the link level' do
        before_all do
          create(:group_group_link, shared_group: shared_group, shared_with_group: shared_with_group,
            group_access: Gitlab::Access::MAINTAINER)
          shared_with_group.add_owner(user)
        end

        it 'tags the shared group at the link cap (LEAST(MAINTAINER, OWNER) = MAINTAINER)' do
          expect(access_levels_by_group(rows)[shared_group.id]).to eq([Gitlab::Access::MAINTAINER])
        end
      end

      context 'and direct access on the sharer is below the link level' do
        let_it_be(:other_shared) { create(:group) }
        let_it_be(:other_sharer) { create(:group) }

        before_all do
          create(:group_group_link, shared_group: other_shared, shared_with_group: other_sharer,
            group_access: Gitlab::Access::MAINTAINER)
          other_sharer.add_reporter(user)
        end

        it 'tags the shared group at the direct cap (LEAST(MAINTAINER, REPORTER) = REPORTER)' do
          expect(access_levels_by_group(rows)[other_shared.id]).to eq([Gitlab::Access::REPORTER])
        end
      end

      context 'when the group link is expired' do
        let_it_be(:expired_link_user) { create(:user) }
        let_it_be(:expired_shared_group) { create(:group) }
        let_it_be(:expired_sharer) { create(:group) }
        let(:user) { expired_link_user }

        before_all do
          create(:group_group_link, shared_group: expired_shared_group, shared_with_group: expired_sharer,
            group_access: Gitlab::Access::MAINTAINER, expires_at: 1.day.ago)
          expired_sharer.add_maintainer(expired_link_user)
        end

        it 'omits the linked group' do
          expect(access_levels_by_group(rows)).not_to have_key(expired_shared_group.id)
        end
      end

      context 'when the membership on the sharer is an access request' do
        let_it_be(:request_user) { create(:user) }
        let_it_be(:request_shared_group) { create(:group) }
        let_it_be(:request_sharer) { create(:group) }
        let(:user) { request_user }

        before_all do
          create(:group_group_link, shared_group: request_shared_group, shared_with_group: request_sharer,
            group_access: Gitlab::Access::MAINTAINER)
          create(:group_member, :reporter, :access_request, group: request_sharer, user: request_user)
        end

        it 'omits the linked group' do
          expect(access_levels_by_group(rows)).not_to have_key(request_shared_group.id)
        end
      end

      context 'when the membership on the sharer is awaiting approval' do
        let_it_be(:awaiting_user) { create(:user) }
        let_it_be(:awaiting_shared_group) { create(:group) }
        let_it_be(:awaiting_sharer) { create(:group) }
        let(:user) { awaiting_user }

        before_all do
          create(:group_group_link, shared_group: awaiting_shared_group, shared_with_group: awaiting_sharer,
            group_access: Gitlab::Access::MAINTAINER)
          create(:group_member, :reporter, :awaiting, group: awaiting_sharer, user: awaiting_user)
        end

        it 'omits the linked group' do
          expect(access_levels_by_group(rows)).not_to have_key(awaiting_shared_group.id)
        end
      end
    end

    context 'when user has both a direct membership and a link on the same group' do
      let_it_be(:other_sharer) { create(:group) }

      before_all do
        group.add_reporter(user)
        create(:group_group_link, shared_group: group, shared_with_group: other_sharer,
          group_access: Gitlab::Access::MAINTAINER)
        other_sharer.add_maintainer(user)
      end

      it 'keeps exact distinct effective roles across direct and linked sources' do
        # Direct = Reporter (20), Linked = LEAST(40, 40) = Maintainer (40).
        expect(access_levels_by_group(rows)[group.id]).to match_array([Gitlab::Access::REPORTER, Gitlab::Access::MAINTAINER])
      end
    end

    context 'when the member is expired' do
      before_all do
        member = create(:group_member, :developer, group: group, user: user, expires_at: 1.day.from_now)
        member.update_column(:expires_at, 1.day.ago)
      end

      it 'omits the expired membership' do
        expect(rows).to be_empty
      end
    end

    context 'when the membership is an access request' do
      let_it_be(:request_user) { create(:user) }
      let_it_be(:request_group) { create(:group) }
      let(:user) { request_user }

      before_all do
        create(:group_member, :reporter, :access_request, group: request_group, user: request_user)
      end

      it 'omits the pending request' do
        expect(access_levels_by_group(rows)).not_to have_key(request_group.id)
      end
    end

    context 'when the membership is awaiting approval' do
      let_it_be(:awaiting_user) { create(:user) }
      let_it_be(:awaiting_group) { create(:group) }
      let(:user) { awaiting_user }

      before_all do
        create(:group_member, :reporter, :awaiting, group: awaiting_group, user: awaiting_user)
      end

      it 'omits the awaiting membership' do
        expect(access_levels_by_group(rows)).not_to have_key(awaiting_group.id)
      end
    end

    context 'when the user is blocked' do
      let_it_be(:blocked_user) { create(:user, :blocked) }
      let_it_be(:blocked_group) { create(:group) }
      let(:user) { blocked_user }

      before_all do
        create(:group_member, :reporter, group: blocked_group, user: blocked_user)
      end

      it 'omits the membership' do
        expect(rows).to be_empty
      end
    end

    context 'when a direct access_level falls below the minimum' do
      before_all do
        group.add_guest(user)
      end

      it 'omits the group' do
        expect(rows).to be_empty
      end
    end

    context 'with access-level caching' do
      before_all do
        group.add_developer(user)
      end

      it 'writes the access-level result under a parallel key' do
        # Cache version is generated per `redis_cache_key` call against the
        # NullStore, so the exact key differs each invocation. Match the
        # distinguishing :access_levels suffix instead.
        allow(Rails.cache).to receive(:read).and_call_original
        allow(Rails.cache).to receive(:write).and_call_original

        rows

        expect(Rails.cache).to have_received(:read).with(ending_with(':access_levels')).at_least(:once)
        expect(Rails.cache).to have_received(:write)
          .with(ending_with(':access_levels'), kind_of(Array), expires_in: described_class::REDIS_CACHE_TTL)
      end

      it 'returns cached access-level rows without querying or writing' do
        cached_rows = [
          {
            organization_id: group.organization_id,
            traversal_ids: group.traversal_ids,
            access_levels: [Gitlab::Access::DEVELOPER]
          }
        ]

        allow(Rails.cache).to receive(:read).with(ending_with(':access_levels')).and_return(cached_rows)
        allow(Rails.cache).to receive(:write).and_call_original

        expect(rows).to eq(cached_rows)
        expect(Rails.cache).not_to have_received(:write).with(ending_with(':access_levels'), anything, anything)
      end

      it 'normalizes cached access-level rows with string keys' do
        cached_rows = [
          {
            'organization_id' => group.organization_id,
            'traversal_ids' => group.traversal_ids,
            'access_levels' => [Gitlab::Access::DEVELOPER]
          }
        ]

        allow(Rails.cache).to receive(:read).with(ending_with(':access_levels')).and_return(cached_rows)
        allow(Rails.cache).to receive(:write).and_call_original

        expect(rows).to eq([
          {
            organization_id: group.organization_id,
            traversal_ids: group.traversal_ids,
            access_levels: [Gitlab::Access::DEVELOPER]
          }
        ])
        expect(Rails.cache).not_to have_received(:write).with(ending_with(':access_levels'), anything, anything)
      end

      it 'treats malformed cached access-level rows as a cache miss' do
        allow(Rails.cache).to receive(:read).with(ending_with(':access_levels'))
          .and_return([{ 'traversal_ids' => group.traversal_ids }])
        allow(Rails.cache).to receive(:write).and_call_original

        expect(access_levels_by_group(rows)[group.id]).to eq([Gitlab::Access::DEVELOPER])
        expect(Rails.cache).to have_received(:write)
          .with(ending_with(':access_levels'), kind_of(Array), expires_in: described_class::REDIS_CACHE_TTL)
      end
    end
  end
end
