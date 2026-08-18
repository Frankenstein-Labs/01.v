# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectsFinder, feature_category: :global_search do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }

    subject(:execute) { described_class.new(user: user).execute }

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has no matching projects' do
      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has direct membership to a project' do
      it 'returns that project' do
        project.add_developer(user)

        expect(execute).to contain_exactly(project)
      end
    end

    context 'when user has direct membership to the project parent group' do
      it 'returns nothing' do
        group.add_developer(user)

        expect(execute).to be_empty
      end
    end

    context 'when user has membership through a shared group link' do
      it 'does not return that project' do
        shared_with_group = create(:group, developers: user)
        create(:group_group_link, shared_with_group: shared_with_group, shared_group: group)

        expect(execute).to be_empty
      end
    end

    context 'when user has membership through a shared project group link' do
      context 'when membership is through a direct group' do
        let_it_be(:shared_with_group) { create(:group, developers: user) }
        let_it_be_with_reload(:project_group_link) do
          create(:project_group_link, project: project, group: shared_with_group)
        end

        it 'returns that project' do
          expect(execute).to contain_exactly(project)
        end

        context 'and the project group link is expired' do
          it 'returns nothing' do
            project_group_link.update!(expires_at: 1.day.ago)

            expect(execute).to be_empty
          end
        end
      end

      context 'when membership is through a descendant group' do
        let_it_be(:parent_group) { create(:group, developers: user) }
        let_it_be(:child_group) { create(:group, parent: parent_group) }
        let_it_be_with_reload(:project_group_link) do
          create(:project_group_link, project: project, group: child_group)
        end

        it 'returns that project' do
          expect(execute).to contain_exactly(project)
        end

        context 'and the project group link is expired' do
          it 'returns nothing' do
            project_group_link.update!(expires_at: 1.day.ago)

            expect(execute).to be_empty
          end
        end
      end

      context 'when project is shared into a sub-group of a group the user already belongs to' do
        let_it_be(:top_level_group) { create(:group) }
        let_it_be(:sub_group) { create(:group, parent: top_level_group) }
        let_it_be(:other_sub_group) { create(:group, parent: top_level_group) }
        let_it_be(:shared_project) { create(:project, :private, group: other_sub_group) }

        context 'when the share link grants the same access level as the group membership' do
          before_all do
            top_level_group.add_guest(user)
            create(:project_group_link, project: shared_project, group: sub_group,
              group_access: Gitlab::Access::GUEST)
          end

          it 'does not return the project because it is already covered by group hierarchy' do
            expect(execute).not_to include(shared_project)
          end
        end

        context 'when the share link grants elevated access above the group membership' do
          before_all do
            top_level_group.add_guest(user)
            create(:project_group_link, project: shared_project, group: sub_group,
              group_access: Gitlab::Access::REPORTER)
          end

          it 'returns the project because the share link provides higher access' do
            expect(execute).to include(shared_project)
          end
        end
      end

      context 'when user is member of mid-level group in deeper hierarchy' do
        let_it_be(:root_group) { create(:group) }
        let_it_be(:mid_level_group) { create(:group, parent: root_group) }
        let_it_be(:deep_child_group) { create(:group, parent: mid_level_group) }
        let_it_be(:project_in_deep_child) { create(:project, :private, group: deep_child_group) }
        let_it_be(:share_target_group) { create(:group, parent: mid_level_group) }

        before_all do
          mid_level_group.add_developer(user)
          create(:project_group_link, project: project_in_deep_child, group: share_target_group,
            group_access: Gitlab::Access::DEVELOPER)
        end

        it 'excludes project covered by mid-level group membership traversal path' do
          expect(execute).not_to include(project_in_deep_child)
        end
      end
    end

    it 'enforces REDIS_CACHE_TTL is shorter than CACHE_VERSION_TTL' do
      expect(described_class::REDIS_CACHE_TTL).to be < described_class::CACHE_VERSION_TTL
    end

    describe 'Redis caching' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }

      before_all do
        project1.add_developer(user)
        project2.add_developer(user)
      end

      before do
        allow(described_class).to receive(:cache_version).and_return('testver')
      end

      it 'caches the result in Redis' do
        cache_key = described_class.redis_cache_key(user.id)
        expect(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Rails.cache).to receive(:write).and_call_original
        expect(Rails.cache).to receive(:write)
          .with(cache_key, match_array([project1.id, project2.id]), expires_in: 5.minutes)

        expect(execute).to contain_exactly(project1, project2)
      end

      it 'uses cached result on subsequent calls' do
        cache_key = described_class.redis_cache_key(user.id)
        cached_ids = [project1.id, project2.id]
        expect(Rails.cache).to receive(:read).with(cache_key).and_return(cached_ids)
        expect(Rails.cache).not_to receive(:write).with(cache_key, anything, anything)

        expect(execute).to contain_exactly(project1, project2)
      end
    end
  end
end
