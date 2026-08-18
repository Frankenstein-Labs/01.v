# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::EligibleApproverGroupsFilter, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:invited_group_with_approver) { create(:project_group_link, project: project).group }
  let_it_be(:invited_group_with_inherited_approver) { create(:project_group_link, project: project).group }
  let_it_be(:project_group_with_inherited_approver) { project.group }
  let_it_be(:parent_group_with_approver) { project.group.parent }

  let(:filter) do
    groups = [
      invited_group_with_approver,
      invited_group_with_inherited_approver,
      project_group_with_inherited_approver,
      parent_group_with_approver
    ]
    group_names = groups.map(&:full_path)

    described_class.new(project, groups: groups, group_names: group_names)
  end

  before_all do
    create(:user, developer_of: invited_group_with_approver)
    invited_group = create(:group_group_link, shared_with_group: invited_group_with_inherited_approver).shared_group
    create(:user, developer_of: invited_group)
    create(:user, owner_of: parent_group_with_approver)
  end

  describe '#output_groups' do
    context 'when using optimized batched query approach' do
      before do
        stub_feature_flags(optimize_codeowners_group_validation: true)
      end

      it 'returns groups with at least one direct member who can approve' do
        expect(filter.output_groups).to contain_exactly(
          invited_group_with_approver,
          parent_group_with_approver
        )
      end
    end

    context 'when using legacy preload approach' do
      let(:fresh_filter) do
        groups = [
          invited_group_with_approver,
          invited_group_with_inherited_approver,
          project_group_with_inherited_approver,
          parent_group_with_approver
        ]
        group_names = groups.map(&:full_path)

        described_class.new(project, groups: groups, group_names: group_names)
      end

      before do
        stub_feature_flags(optimize_codeowners_group_validation: false)
      end

      it 'returns groups with at least one direct member who can approve' do
        expect(fresh_filter.output_groups).to contain_exactly(
          invited_group_with_approver,
          parent_group_with_approver
        )
      end
    end

    context 'when no groups have eligible approvers' do
      let(:group_without_members) { create(:group) }
      let(:filter) do
        described_class.new(
          project,
          groups: [group_without_members],
          group_names: [group_without_members.full_path]
        )
      end

      it 'returns empty array' do
        expect(filter.output_groups).to be_empty
      end
    end

    context 'when group has only guests' do
      let(:group_with_guest) { create(:project_group_link, project: project).group }
      let(:filter) do
        described_class.new(
          project,
          groups: [group_with_guest],
          group_names: [group_with_guest.full_path]
        )
      end

      before do
        create(:user, guest_of: group_with_guest)
      end

      it 'does not return the group' do
        expect(filter.output_groups).to be_empty
      end
    end

    context 'when input groups is empty' do
      let(:filter) do
        described_class.new(project, groups: [], group_names: [])
      end

      it 'returns empty array' do
        expect(filter.output_groups).to be_empty
      end
    end

    context 'when testing logging behavior' do
      let(:groups) do
        [
          invited_group_with_approver,
          invited_group_with_inherited_approver,
          project_group_with_inherited_approver,
          parent_group_with_approver
        ]
      end

      let(:group_names) { groups.map(&:full_path) }

      let(:fresh_filter) { described_class.new(project, groups: groups, group_names: group_names) }

      context 'when logging feature flag is enabled' do
        before do
          stub_feature_flags(log_codeowners_validation_user_ids: true)
        end

        context 'when using optimized batched query approach' do
          before do
            stub_feature_flags(optimize_codeowners_group_validation: true)
          end

          it 'logs the number of user IDs loaded' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                message: "CODEOWNERS group validation user IDs loaded",
                project_id: project.id,
                groups_count: 4
              )
            )

            fresh_filter.output_groups
          end
        end

        context 'when using legacy preload approach' do
          before do
            stub_feature_flags(optimize_codeowners_group_validation: false)
          end

          it 'logs the number of user IDs loaded' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                message: "CODEOWNERS group validation user IDs loaded",
                project_id: project.id,
                groups_count: 4
              )
            )

            fresh_filter.output_groups
          end
        end
      end

      context 'when logging feature flag is disabled' do
        before do
          stub_feature_flags(log_codeowners_validation_user_ids: false)
        end

        it 'does not log' do
          expect(Gitlab::AppLogger).not_to receive(:info)

          fresh_filter.output_groups
        end
      end
    end

    it 'memoizes the result' do
      first_result = filter.output_groups
      second_result = filter.output_groups

      expect(first_result.object_id).to eq(second_result.object_id)
    end
  end

  describe '#invalid_group_names' do
    it 'returns all group names that do not match an eligible approver group' do
      expect(filter.invalid_group_names).to contain_exactly(
        invited_group_with_inherited_approver.full_path,
        project_group_with_inherited_approver.full_path
      )
    end

    it 'memoizes the result' do
      first_result = filter.invalid_group_names
      second_result = filter.invalid_group_names

      expect(first_result.object_id).to eq(second_result.object_id)
    end
  end

  describe '#valid_group_names' do
    it 'returns all group names that match an eligible approver group' do
      expect(filter.valid_group_names).to contain_exactly(
        invited_group_with_approver.full_path,
        parent_group_with_approver.full_path
      )
    end

    it 'memoizes the result' do
      first_result = filter.valid_group_names
      second_result = filter.valid_group_names

      expect(first_result.object_id).to eq(second_result.object_id)
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:group_without_eligible_approvers)
    end
  end

  # Increasing the number of groups should not result in N+1 queries
  it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
    # Reload the project manually, outside of the control
    project_id = project.id
    project = Project.find(project_id)
    groups = [
      invited_group_with_approver,
      invited_group_with_inherited_approver,
      project_group_with_inherited_approver,
      parent_group_with_approver
    ]
    group_names = groups.map(&:full_path)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.valid_group_names
      filter.invalid_group_names
    end
    # Clear the RequestStore to ensure we do not have a warm cache
    RequestStore.clear!

    extra_group_without_approver = create(:project_group_link, project: project).group
    extra_group_with_approver = create(:project_group_link, project: project).group
    create(:user, developer_of: extra_group_with_approver)

    groups += [extra_group_without_approver, extra_group_with_approver]
    group_names = groups.map(&:full_path)
    # Refind the project to reset the associations
    project = Project.find(project_id)

    expect do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.valid_group_names
      filter.invalid_group_names
    end.not_to exceed_query_limit(control.count)
  end

  context 'when project has no members with sufficient access' do
    let_it_be(:empty_project) { create(:project) }
    let(:group) { create(:group) }
    let(:filter) do
      described_class.new(
        empty_project,
        groups: [group],
        group_names: [group.full_path]
      )
    end

    before do
      create(:user, developer_of: group)
    end

    it 'returns empty array' do
      expect(filter.output_groups).to be_empty
    end
  end

  context 'with different access levels' do
    let(:group_with_maintainer) { create(:project_group_link, project: project).group }
    let(:group_with_owner) { create(:project_group_link, project: project).group }
    let(:group_with_reporter) { create(:project_group_link, project: project).group }

    let(:filter) do
      groups = [group_with_maintainer, group_with_owner, group_with_reporter]
      described_class.new(
        project,
        groups: groups,
        group_names: groups.map(&:full_path)
      )
    end

    before do
      create(:user, maintainer_of: group_with_maintainer)
      create(:user, owner_of: group_with_owner)
      create(:user, reporter_of: group_with_reporter)
    end

    it 'includes groups with maintainer and owner access' do
      expect(filter.output_groups).to contain_exactly(
        group_with_maintainer,
        group_with_owner
      )
    end

    it 'excludes groups with only reporter access' do
      expect(filter.output_groups).not_to include(group_with_reporter)
    end
  end

  context 'with namespace bans' do
    let_it_be(:user_banned_in_project_namespace) { create(:user) }
    let_it_be(:group_with_banned_user) { create(:project_group_link, project: project).group }
    let_it_be(:group_with_user_banned_elsewhere) { create(:project_group_link, project: project).group }
    let_it_be(:unrelated_namespace) { create(:group) }

    let(:filter) do
      groups = [group_with_banned_user, group_with_user_banned_elsewhere]
      described_class.new(
        project,
        groups: groups,
        group_names: groups.map(&:full_path)
      )
    end

    before_all do
      # User banned in the project's root namespace - should be excluded
      group_with_banned_user.add_developer(user_banned_in_project_namespace)
      project.add_developer(user_banned_in_project_namespace)
      create(:namespace_ban, user: user_banned_in_project_namespace, namespace: project.root_namespace)

      # User banned in an unrelated namespace - should NOT be excluded
      user_banned_elsewhere = create(:user, developer_of: group_with_user_banned_elsewhere)
      project.add_developer(user_banned_elsewhere)
      create(:namespace_ban, user: user_banned_elsewhere, namespace: unrelated_namespace)
    end

    it 'excludes groups with users banned in the project root namespace' do
      expect(filter.output_groups).not_to include(group_with_banned_user)
    end

    it 'includes groups with users banned in unrelated namespaces' do
      expect(filter.output_groups).to include(group_with_user_banned_elsewhere)
    end
  end
end
