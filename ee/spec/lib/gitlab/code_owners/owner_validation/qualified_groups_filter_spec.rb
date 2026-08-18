# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::OwnerValidation::QualifiedGroupsFilter, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let_it_be(:user_project) { create(:project, :in_user_namespace) }
  let_it_be(:guest_group) do
    group = create(:group, name: 'Guest')
    create(:project_group_link, :guest, project: project, group: group)
    create(:project_group_link, :guest, project: user_project, group: group)
    group
  end

  let_it_be(:planner_group) do
    group = create(:group, name: 'Planner')
    create(:project_group_link, :planner, project: project, group: group)
    create(:project_group_link, :planner, project: user_project, group: group)
    group
  end

  let_it_be(:reporter_group) do
    group = create(:group, name: 'Reporter')
    create(:project_group_link, :reporter, project: project, group: group)
    create(:project_group_link, :reporter, project: user_project, group: group)
    group
  end

  let_it_be(:developer_group) do
    group = create(:group, name: 'Developer')
    create(:project_group_link, :developer, project: project, group: group)
    create(:project_group_link, :developer, project: user_project, group: group)
    group
  end

  let_it_be(:maintainer_group) do
    group = create(:group, name: 'Maintainer')
    create(:project_group_link, :maintainer, project: project, group: group)
    create(:project_group_link, :maintainer, project: user_project, group: group)
    group
  end

  let_it_be(:owner_group) do
    group = create(:group, name: 'Owner')
    create(:project_group_link, :owner, project: project, group: group)
    create(:project_group_link, :owner, project: user_project, group: group)
    group
  end

  let_it_be(:project_group) { project.group }
  let_it_be(:parent_group) { project_group.parent }
  let_it_be(:developer_subgroup_of_parent_group) { create(:group, name: 'Dev Sub of Parent', parent: parent_group) }

  let_it_be(:external_group) { create(:group, :nested, name: 'External Nested') }

  let_it_be(:nested_group) do
    group = create(:group, :nested, name: 'Nested')
    create(:project_group_link, :developer, project: project, group: group)
    create(:project_group_link, :developer, project: user_project, group: group)
    group
  end

  let_it_be(:project_group_shared_with_group) do
    create(:group_group_link, shared_group: project_group).shared_with_group
  end

  let_it_be(:parent_group_shared_with_group) do
    create(:group_group_link, shared_group: parent_group).shared_with_group
  end

  let_it_be(:parent_group_shared_with_reporter_group) do
    create(:group_group_link, :reporter, shared_group: parent_group).shared_with_group
  end

  let_it_be(:project_group_shared_with_reporter_group) do
    create(:group_group_link, :reporter, shared_group: project_group).shared_with_group
  end

  let_it_be(:group_shared_with_project_group) do
    create(:group_group_link, shared_with_group: project_group).shared_group
  end

  let_it_be(:group_shared_with_parent_group) do
    create(:group_group_link, shared_with_group: parent_group).shared_group
  end

  # Group relationship diagram for `project`
  #
  # # Parent group and ancestors
  # parent_group
  #   |- project_group
  #     |- project
  #
  # # Direct project access:
  #
  # project --- guest_group (Guest)
  #          |- planner_group (Planner)
  #          |- reporter_group (Reporter)
  #          |- developer_group (Developer)
  #          |- maintainer_group (Maintainer)
  #          |- owner_group (Owner)
  #          |- nested_group (Developer)
  #
  # # Groups the project group and ancestors are shared with:
  #
  # project_group     --- project_group_shared_with_group (Developer)
  #                    |- project_group_shared_with_reporter_group (Reporter)
  # parent_group      --- parent_group_shared_with_group (Developer)
  #                    |- parent_group_shared_with_reporter_group (Reporter)
  #
  # # Groups shared with the project group and ancestors
  #
  # group_shared_with_project_group --- project_group (Developer)
  # group_shared_with_parent_group  --- parent_group (Developer)
  #
  # # Project in a group that shares a common ancestor
  #
  # parent_group --- developer_subgroup_of_parent_group (Developer)
  #
  # # No relationship to project
  #
  # external_group

  # Group relationship diagram for `user_project`
  #
  # # User Namespace
  # user_namespace
  #   |- user_project
  #
  # # Direct project access:
  #
  # project --- guest_group (Guest)
  #          |- planner_group (Planner)
  #          |- reporter_group (Reporter)
  #          |- developer_group (Developer)
  #          |- maintainer_group (Maintainer)
  #          |- owner_group (Owner)
  #          |- nested_group (Developer)
  #
  # # No relationship to project
  #
  # project_group
  # parent_group
  # project_group_shared_with_group
  # project_group_shared_with_reporter_group
  # parent_group_shared_with_group
  # parent_group_shared_with_reporter_group
  # group_shared_with_project_group
  # group_shared_with_parent_group
  # dev_sub_of_parent
  # developer_subgroup_of_parent_group
  # external_group

  let_it_be(:groups) do
    [
      project_group,
      parent_group,
      guest_group,
      planner_group,
      reporter_group,
      developer_group,
      maintainer_group,
      owner_group,
      nested_group,
      project_group_shared_with_group,
      project_group_shared_with_reporter_group,
      parent_group_shared_with_group,
      parent_group_shared_with_reporter_group,
      group_shared_with_project_group,
      group_shared_with_parent_group,
      developer_subgroup_of_parent_group,
      external_group
    ]
  end

  let(:group_names) { groups.map(&:full_path) }
  let(:filter) { described_class.new(project, groups: groups, group_names: group_names) }

  describe '#output_groups' do
    context 'when project is in a group' do
      it 'returns ancestoral groups and developer groups shared with ancestoral groups and invited developer groups' do
        expect(filter.output_groups).to contain_exactly(
          developer_group,
          maintainer_group,
          owner_group,
          nested_group,
          project_group,
          parent_group,
          project_group_shared_with_group,
          parent_group_shared_with_group
        )
      end
    end

    context 'when project is in a user namespace' do
      let(:filter) { described_class.new(user_project, groups: groups, group_names: group_names) }

      it 'does not raise an error when attempting to find shared with groups' do
        expect(filter.output_groups).to contain_exactly(
          developer_group,
          maintainer_group,
          owner_group,
          nested_group
        )
      end
    end
  end

  describe '#valid_group_names' do
    it 'returns all group names that match a qualified group' do
      expect(filter.valid_group_names).to contain_exactly(
        developer_group.full_path,
        maintainer_group.full_path,
        owner_group.full_path,
        nested_group.full_path,
        project_group.full_path,
        parent_group.full_path,
        project_group_shared_with_group.full_path,
        parent_group_shared_with_group.full_path
      )
    end
  end

  describe '#invalid_group_names' do
    it 'returns all group names that do not match a qualified group' do
      expect(filter.invalid_group_names).to contain_exactly(
        guest_group.full_path,
        planner_group.full_path,
        reporter_group.full_path,
        external_group.full_path,
        developer_subgroup_of_parent_group.full_path,
        project_group_shared_with_reporter_group.full_path,
        parent_group_shared_with_reporter_group.full_path,
        group_shared_with_project_group.full_path,
        group_shared_with_parent_group.full_path
      )
    end
  end

  describe '#error_message' do
    it 'returns an error message key to be applied to invalid entries' do
      expect(filter.error_message).to eq(:unqualified_group)
    end
  end

  describe '#valid_entry?(references)' do
    let(:references) { instance_double(Gitlab::CodeOwners::ReferenceExtractor, names: names) }
    let(:names) { ['bar'] }
    let(:invalid_group_names) { ['foo'] }

    before do
      allow(filter).to receive(:invalid_group_names).and_return(invalid_group_names)
    end

    context 'when references contains no invalid references' do
      it 'returns true' do
        expect(filter.valid_entry?(references)).to be(true)
      end
    end

    context 'when references.names includes invalid_group_names' do
      let(:names) { %w[foo bar] }

      it 'returns false' do
        expect(filter.valid_entry?(references)).to be(false)
      end
    end
  end

  it 'does not perform N+1 queries', :request_store, :use_sql_query_cache do
    project_id = project.id
    # refind the project to ensure the associations aren't loaded
    project = Project.find(project_id)
    groups = [
      guest_group,
      planner_group,
      reporter_group,
      developer_group,
      maintainer_group,
      owner_group,
      project_group,
      parent_group,
      project_group_shared_with_group,
      parent_group_shared_with_group,
      group_shared_with_project_group,
      group_shared_with_parent_group
    ]
    group_names = groups.map(&:full_path)

    control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.invalid_group_names
      filter.valid_group_names
    end

    # Reset the request store to ensure the cache isn't warm
    RequestStore.clear!

    additional_group = create(:project_group_link, project: project).group
    groups << additional_group
    group_names << additional_group.full_path

    additional_shared_with_group = create(:group_group_link, shared_group: project_group).shared_with_group
    groups << additional_shared_with_group
    group_names << additional_shared_with_group.full_path

    # refind the project and groups to ensure the associations aren't loaded
    project = Project.find(project_id)

    expect do
      filter = described_class.new(project, groups: groups, group_names: group_names)
      filter.output_groups
      filter.invalid_group_names
      filter.valid_group_names
    end.to issue_same_number_of_queries_as(control)
  end
end
