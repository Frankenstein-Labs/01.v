# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::GroupsLoader, feature_category: :source_code_management do
  describe '#load_to' do
    let(:loader) { described_class.new(instance_double(Project)) }
    let(:entry) { instance_double(Gitlab::CodeOwners::Entry) }
    let(:groups) { 'groups collection' }

    before do
      allow(loader).to receive(:groups).and_return(groups)
      allow(entry).to receive(:add_matching_groups_from)
    end

    it 'asks each entry to assign matching groups' do
      loader.load_to([entry])

      expect(loader).to have_received(:groups)
      expect(entry).to have_received(:add_matching_groups_from).with(groups)
    end
  end

  describe '#groups' do
    let(:names_kwarg) { group_names }

    # Group relationship diagram:
    #
    # # Parent group and ancestors
    # parent_group
    #   |- project_group
    #     |- project
    #
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
    # project_group --- project_group_shared_with_group (Developer)
    #                |- project_group_shared_with_reporter_group (Reporter)
    # parent_group  --- parent_group_shared_with_group (Developer)
    #                |- parent_group_shared_with_reporter_group (Reporter)
    #
    # # Groups shared with the project group and ancestors
    #
    # group_shared_with_project_group --- project_group (Developer)
    # group_shared_with_parent_group  --- parent_group (Developer)
    #
    # # No relationship to project
    #
    # external_group

    let_it_be(:project) { create(:project, :in_subgroup) }
    let_it_be(:guest_group) { create(:project_group_link, :guest, project: project).group }
    let_it_be(:planner_group) { create(:project_group_link, :planner, project: project).group }
    let_it_be(:reporter_group) { create(:project_group_link, :reporter, project: project).group }
    let_it_be(:developer_group) { create(:project_group_link, :developer, project: project).group }
    let_it_be(:maintainer_group) { create(:project_group_link, :maintainer, project: project).group }
    let_it_be(:owner_group) { create(:project_group_link, :owner, project: project).group }
    let_it_be(:project_group) { project.group }
    let_it_be(:parent_group) { project_group.parent }
    let_it_be(:external_group) { create(:group, :nested) }

    let_it_be(:nested_group) do
      create(:project_group_link, :developer, project: project, group: create(:group, :nested)).group
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

    let_it_be(:invited_groups) do
      [
        guest_group,
        planner_group,
        reporter_group,
        developer_group,
        maintainer_group,
        owner_group,
        nested_group
      ]
    end

    let_it_be(:project_group_and_ancestors) do
      [
        project_group,
        parent_group
      ]
    end

    let_it_be(:project_group_and_ancestors_shared_with_groups) do
      [
        project_group_shared_with_group,
        parent_group_shared_with_group
      ]
    end

    let_it_be(:project_group_and_ancestors_shared_with_groups_without_access) do
      [
        project_group_shared_with_reporter_group,
        parent_group_shared_with_reporter_group
      ]
    end

    let_it_be(:groups_shared_with_project_group_and_ancestors) do
      [
        group_shared_with_project_group,
        group_shared_with_parent_group
      ]
    end

    let_it_be(:groups) do
      [
        *invited_groups,
        external_group,
        *project_group_and_ancestors,
        *project_group_and_ancestors_shared_with_groups,
        *project_group_and_ancestors_shared_with_groups_without_access,
        *groups_shared_with_project_group_and_ancestors
      ]
    end

    let_it_be(:group_names) { groups.map(&:full_path) }

    subject { described_class.new(project, names: names_kwarg).groups }

    it 'returns all valid groups', :aggregate_failures do
      is_expected.to match_array(
        invited_groups +
        project_group_and_ancestors +
        project_group_and_ancestors_shared_with_groups
      )

      is_expected.not_to include(
        external_group,
        *project_group_and_ancestors_shared_with_groups_without_access,
        *groups_shared_with_project_group_and_ancestors
      )
    end

    context 'when names attr is nil' do
      let(:names_kwarg) { nil }

      it { is_expected.to be_empty }
    end

    context 'when names attr is empty' do
      let(:names_kwarg) { [] }

      it { is_expected.to be_empty }
    end

    context 'there are no matches' do
      let(:names_kwarg) { ['foo/bar'] }

      it { is_expected.to be_empty }
    end

    context 'with organization isolation' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- existing spec has many helpers; isolation tests add a few more
      let_it_be(:organization) { create(:organization, :isolated) }
      let_it_be(:other_organization) { create(:organization) }

      context 'when the project organization is isolated' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- existing spec has many helpers; isolation tests add a few more
        let_it_be(:isolated_project) { create(:project, organization: organization) }
        let_it_be(:same_org_group) do
          group = create(:group, name: 'SameOrg', organization: organization)
          create(:project_group_link, :developer, project: isolated_project, group: group)
          group
        end

        let_it_be(:cross_org_group) do
          group = create(:group, name: 'CrossOrg', organization: other_organization)
          create(:project_group_link, :developer, project: isolated_project, group: group)
          group
        end

        subject(:loader) do
          described_class.new(isolated_project, names: [same_org_group.full_path, cross_org_group.full_path])
        end

        it 'excludes groups from a different organization', :aggregate_failures do
          expect(loader.groups).to include(same_org_group)
          expect(loader.groups).not_to include(cross_org_group)
        end
      end

      context 'when the project organization is not isolated' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- existing spec has many helpers; isolation tests add a few more
        let_it_be(:non_isolated_project) { create(:project, organization: other_organization) }
        let_it_be(:cross_org_invited_group) do
          group = create(:group, name: 'FromIsolatedOrg', organization: organization)
          create(:project_group_link, :developer, project: non_isolated_project, group: group)
          group
        end

        subject(:loader) { described_class.new(non_isolated_project, names: [cross_org_invited_group.full_path]) }

        it 'returns groups from other organizations' do
          expect(loader.groups).to include(cross_org_invited_group)
        end
      end
    end
  end
end
