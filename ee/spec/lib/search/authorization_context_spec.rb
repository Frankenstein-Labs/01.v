# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::AuthorizationContext, feature_category: :global_search do
  let(:current_user) { create(:user) }
  let(:context) { described_class.new(current_user) }

  describe '#get_access_levels_for_feature' do
    it 'returns role required to access the passed feature' do
      expect(context.get_access_levels_for_feature('repository'))
          .to eq({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })
    end
  end

  describe '#get_traversal_ids_for_group' do
    it 'returns elastic_namespace_ancestry for a group_id' do
      group = create(:group)

      expect(context.get_traversal_ids_for_group(group.id)).to eq(group.elastic_namespace_ancestry)
    end
  end

  describe '#get_groups_for_user' do
    let(:options) { { search_level: :project, project_ids: [1, 2], features: [:foo], min_access_level: 10 } }
    let(:stubbed_value) { %w[123-456- 789-012-] }

    it 'calls Elastic::Filters.groups_for_user with current_user and min_access_level' do
      expect(context).to receive(:groups_for_user)
        .with(user: current_user, min_access_level: 10).and_return(stubbed_value)
      expect(context.get_groups_for_user(options)).to eq(stubbed_value)
    end
  end

  describe '#get_projects_for_user' do
    let_it_be(:group) { create(:group, :with_hierarchy) }
    let_it_be(:project1) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group.children[0]) }
    let_it_be(:project3) { create(:project, group: group.children[1]) }
    let_it_be(:project4) { create(:project, group: group.children[1].children[1]) }
    let_it_be(:project5) { create(:project, group: group.children[1].children[0]) }
    let_it_be(:project6) { create(:project, group: group.children[1].children[0].children[0]) }
    let_it_be(:project7) { create(:project) }
    let_it_be(:project9) { create(:project, group: group.children[1].children[0].children[0]) }
    let(:options) do
      { search_level: :global, min_access_level: Gitlab::Access::DEVELOPER }
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it 'returns empty Project relation' do
        expect(context.get_projects_for_user(options)).to match_array(Project.none)
      end
    end

    context 'when user is not nil' do
      let_it_be(:current_user) { create(:user) }

      before do
        [project1, project2, project3, project4, project5, project6, project7].each do |project|
          project.add_developer(current_user)
        end
      end

      it 'calls where_exists(current_user.authorizations_for_projects(min_access_level:) on project relations' do
        projects_for_user = Project.id_in([project1, project2])
        allow(context).to receive(:projects_for_user).with(current_user, options).and_return(projects_for_user)
        min_access_level_projects = Project.id_in([project1])
        allow(current_user).to receive(:authorizations_for_projects).with(min_access_level: Gitlab::Access::DEVELOPER)
          .and_return(min_access_level_projects)

        expect(projects_for_user).to receive(:where_exists).with(min_access_level_projects)

        context.get_projects_for_user(options)
      end

      context 'when search_level is global' do
        it 'returns all projects the user has access to' do
          final_list_projects = Project.id_in([project1, project2, project3, project4, project5, project6, project7])
          expect(context.get_projects_for_user(options)).to match_array(final_list_projects)
        end
      end

      context 'when search_level is group' do
        let(:options) do
          { search_level: :group, group_ids: [group.children[1]], min_access_level: Gitlab::Access::GUEST }
        end

        it 'returns all projects the user has access to within the group' do
          final_list_projects = Project.id_in([project3, project4, project5, project6])
          expect(context.get_projects_for_user(options)).to match_array(final_list_projects)
        end
      end

      context 'when search_level is project' do
        context 'when projects are not existing for the passed project_ids' do
          let(:options) do
            { search_level: :project, project_ids: [non_existing_record_id], min_access_level: Gitlab::Access::GUEST }
          end

          it 'returns empty Project relation' do
            expect(context.get_projects_for_user(options)).to match_array(Project.none)
          end
        end

        context 'when passed project is present in the authorized projects' do
          let(:options) do
            { search_level: :project, project_ids: [project5.id], min_access_level: Gitlab::Access::GUEST }
          end

          it 'returns Project relation with given project' do
            expect(context.get_projects_for_user(options)).to match_array(Project.id_in(project5.id))
          end
        end

        context 'when passed project is not present in the authorized projects' do
          let(:options) do
            { search_level: :project, project_ids: [project9.id], min_access_level: Gitlab::Access::GUEST }
          end

          it 'returns empty Project relation' do
            expect(context.get_projects_for_user(options)).to match_array(Project.none)
          end
        end
      end
    end

    context 'when a project is shared into a group inside the user\'s authorized group hierarchy' do
      let_it_be(:current_user) { create(:user) }
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: top_level_group) }
      let_it_be(:other_sub_group) { create(:group, parent: top_level_group) }
      let_it_be(:project_inside_hierarchy) { create(:project, :private, group: other_sub_group) }

      let(:context) { described_class.new(current_user) }

      before_all do
        top_level_group.add_developer(current_user)
        create(:project_group_link, project: project_inside_hierarchy, group: sub_group)
      end

      it 'does not return the project as it is already covered by group traversal membership' do
        options = { search_level: :group, group_ids: [top_level_group.id], min_access_level: Gitlab::Access::GUEST }
        result = context.get_projects_for_user(options)

        expect(result).not_to include(project_inside_hierarchy)
      end
    end
  end

  describe '#get_groups_with_custom_roles' do
    let(:authorized_groups) { [1, 2, 3] }
    let(:user_abilities) { { 1 => ['read_repository'], 2 => ['read_repository'], 3 => [] } }
    let(:allowed_ids) { [1, 2] }
    let(:group_relation) { instance_double(ActiveRecord::Relation) }
    let(:authz_group) { instance_double(::Authz::Group, permitted: user_abilities) }

    before do
      allow(::Authz::Group).to receive(:new).with(current_user, scope: authorized_groups)
        .and_return(authz_group)
      allow(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)
      allow(Group).to receive(:id_in).with(allowed_ids).and_return(group_relation)
    end

    it 'returns empty relation if authorized_groups is empty' do
      expect(context.get_groups_with_custom_roles([])).to be_empty
    end

    it 'returns groups filtered by custom role permissions for repository feature' do
      expect(context.get_groups_with_custom_roles(authorized_groups)).to eq(group_relation)
    end

    it 'calls Authz::Group with current_user and authorized_groups scope' do
      expect(::Authz::Group).to receive(:new).with(current_user, scope: authorized_groups)
        .and_return(authz_group)

      context.get_groups_with_custom_roles(authorized_groups)
    end

    it 'filters groups by repository feature abilities' do
      expect(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)

      context.get_groups_with_custom_roles(authorized_groups)
    end
  end

  describe '#get_projects_with_custom_roles' do
    let(:authorized_projects) { [1, 2, 3] }
    let(:user_abilities) { { 1 => ['read_repository'], 2 => ['read_repository'], 3 => [] } }
    let(:allowed_ids) { [1, 2] }
    let(:project_relation) { instance_double(ActiveRecord::Relation) }
    let(:authz_project) { instance_double(::Authz::Project, permitted: user_abilities) }

    before do
      allow(::Authz::Project).to receive(:new).with(current_user, scope: authorized_projects)
        .and_return(authz_project)
      allow(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)
      allow(Project).to receive(:id_in).with(allowed_ids).and_return(project_relation)
    end

    it 'returns empty relation if authorized_groups is empty' do
      expect(context.get_projects_with_custom_roles([])).to be_empty
    end

    it 'returns projects filtered by custom role permissions for repository feature' do
      expect(context.get_projects_with_custom_roles(authorized_projects)).to eq(project_relation)
    end

    it 'calls Authz::Project with current_user and authorized_projects scope' do
      expect(::Authz::Project).to receive(:new).with(current_user, scope: authorized_projects)
        .and_return(authz_project)

      context.get_projects_with_custom_roles(authorized_projects)
    end

    it 'filters projects by repository feature abilities' do
      expect(context).to receive(:allowed_ids_by_ability)
        .with(feature: 'repository', user_abilities: user_abilities)
        .and_return(allowed_ids)

      context.get_projects_with_custom_roles(authorized_projects)
    end
  end

  describe '#admin_user?' do
    context 'when user is nil' do
      let(:current_user) { nil }

      it 'returns false' do
        expect(context.admin_user?).to be false
      end
    end

    context 'when user can read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'returns true' do
        expect(context.admin_user?).to be true
      end
    end

    context 'when user cannot read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(false)
      end

      it 'returns false' do
        expect(context.admin_user?).to be false
      end
    end
  end

  describe '#anonymous_user?' do
    context 'when user is nil' do
      let(:current_user) { nil }

      it 'returns true' do
        expect(context.anonymous_user?).to be true
      end
    end

    context 'when user is present' do
      it 'returns false' do
        expect(context.anonymous_user?).to be false
      end
    end
  end
end
