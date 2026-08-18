# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::AccessBranchBuilder, feature_category: :global_search do
  subject(:builder) { described_class.new(current_user, auth, options) }

  let(:current_user) { create(:user) }
  let(:auth) { instance_double(::Search::AuthorizationContext) }
  let(:options) do
    {
      group_id: 1,
      project_id: [],
      search_level: :group,
      features: 'repository'
    }
  end

  before do
    allow(auth).to receive(:get_access_levels_for_feature).with('repository')
      .and_return({ project: ::Gitlab::Access::GUEST, private_project: ::Gitlab::Access::REPORTER })
    allow(auth).to receive_messages(
      get_projects_for_user: Project.none,
      get_groups_for_user: Group.none,
      get_formatted_traversal_ids_for_groups: [],
      get_groups_with_custom_roles: Group.none,
      get_projects_with_custom_roles: Project.none
    )
    # By default, assume traversal_id_search is available to not break existing tests
    allow(::Search::Zoekt).to receive(:feature_available?)
      .with(:traversal_id_search, anything, anything)
      .and_return(true)
  end

  describe '#build' do
    context 'when current_user can read all resources' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'returns admin branch only' do
        result = builder.build

        expect(result.first.dig(:meta, :key)).to eq('repository_access_level')
        expect(result.first.dig(:meta, :value)).to eq('20|10')
        expect(result.first.dig(:_context, :name)).to eq('admin_branch')
      end
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'returns public branch only' do
        result = builder.build

        expect(result.first).to include(:and)
        expect(result.first.dig(:_context, :name)).to eq('public_branch')
      end
    end

    context 'when current_user is authenticated but not admin' do
      context 'when access to projects as GUEST and REPORTER' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          guest_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 55, 99], count: 3)
          reporter_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [2], count: 1)

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_projects)

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_projects)
        end

        it 'returns all branch types' do
          result = builder.build
          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }

          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access to projects as GUEST only' do
        let(:guest_projects) { class_double(ApplicationRecord, exists?: true, pluck_primary_key: [1, 55, 99]) }

        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_projects)
        end

        it 'returns public and internal auth branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch'
          )
        end

        context 'and has access with a custom role' do
          before do
            allow(auth).to receive(:get_projects_with_custom_roles)
              .with(guest_projects)
              .and_return(guest_projects)
          end

          it 'returns public and internal auth branch types' do
            result = builder.build

            branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
            expect(branch_contexts).to contain_exactly(
              'public_and_internal_branch',
              'public_and_internal_authorized_branch',
              'private_authorized_branch'
            )
          end
        end
      end

      context 'when access to projects as REPORTER only' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          reporter_projects = class_double(ApplicationRecord, exists?: true, pluck_primary_key: [2])

          allow(auth).to receive(:get_projects_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_projects)
        end

        it 'returns private auth branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access to group as GUEST and REPORTER' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          guest_groups = class_double(ApplicationRecord, exists?: true,
            pluck: [[123], [456]])
          reporter_groups = class_double(ApplicationRecord, exists?: true,
            pluck: [[789]])

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_groups)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(guest_groups, hash_including(search_level: :group))
            .and_return(%w[123- 456-])

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(reporter_groups, hash_including(search_level: :group))
            .and_return(['789-'])
        end

        it 'returns all branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch',
            'private_authorized_branch'
          )
        end
      end

      context 'when access group to as GUEST only' do
        let(:guest_groups) { class_double(ApplicationRecord, exists?: true, pluck: [[123], [456]]) }

        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(guest_groups, hash_including(search_level: :group))
            .and_return(%w[123- 456-])
        end

        it 'returns all public and internal branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'public_and_internal_authorized_branch'
          )
        end

        context 'and has access with a custom role' do
          before do
            allow(auth).to receive(:get_groups_with_custom_roles)
              .with(guest_groups)
              .and_return(guest_groups)
          end

          it 'returns public and internal auth branch types' do
            result = builder.build

            branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
            expect(branch_contexts).to contain_exactly(
              'public_and_internal_branch',
              'public_and_internal_authorized_branch',
              'private_authorized_branch'
            )
          end
        end
      end

      context 'when access to group as REPORTER only' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(false)

          reporter_groups = class_double(ApplicationRecord, exists?: true,
            pluck: [[1], [56], [99]])

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
            .and_return(reporter_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(reporter_groups, hash_including(search_level: :group))
            .and_return(%w[1- 56- 99-])
        end

        it 'returns all branch types' do
          result = builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to contain_exactly(
            'public_and_internal_branch',
            'private_authorized_branch'
          )
        end
      end
    end

    context 'when no authorization filters are available' do
      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(false)
      end

      it 'returns only public and internal branches' do
        result = builder.build

        branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
        expect(branch_contexts).to contain_exactly('public_and_internal_branch')
      end
    end

    context 'when enforcing project limit' do
      let_it_be(:_) { create(:application_setting) }

      let(:many_project_ids) { (1..10).to_a }
      let(:limited_project_ids) { (1..3).to_a }
      let(:guest_projects) do
        class_double(ApplicationRecord, exists?: true, pluck_primary_key: many_project_ids, count: 10)
      end

      let(:reporter_projects) { class_double(ApplicationRecord, exists?: true, pluck_primary_key: [], count: 0) }

      before do
        allow(current_user).to receive(:can_read_all_resources?).and_return(false)

        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
          .and_return(guest_projects)

        allow(auth).to receive(:get_projects_for_user)
          .with(hash_including(min_access_level: ::Gitlab::Access::REPORTER))
          .and_return(reporter_projects)

        stub_ee_application_setting(zoekt_max_projects_for_legacy_search: 3)
      end

      context 'when traversal_id_search is not available' do
        before do
          allow(::Search::Zoekt).to receive(:feature_available?)
            .with(:traversal_id_search, current_user, group_id: 1, project_id: [])
            .and_return(false)
        end

        it 'limits projects to zoekt_max_projects_legacy_search' do
          result = builder.build

          # Extract repo IDs from public_and_internal_authorized_branch
          auth_branch = result.find { |branch| branch.dig(:_context, :name) == 'public_and_internal_authorized_branch' }
          repo_ids = auth_branch.dig(:and, :children, 2, :or, :children, 0, :repo_ids)

          expect(repo_ids).to eq(limited_project_ids)
          expect(repo_ids.size).to eq(3)
        end

        it 'skips group filters when limiting projects' do
          result = builder.build

          # Verify no group-based traversal ID filters are present in the authorized branch
          auth_branch = result.find { |branch| branch.dig(:_context, :name) == 'public_and_internal_authorized_branch' }

          # The branch should exist with project IDs only, no traversal IDs
          expect(auth_branch).to be_present
          repo_filter = auth_branch.dig(:and, :children, 2, :or, :children, 0)
          expect(repo_filter).to have_key(:repo_ids)
          expect(repo_filter).not_to have_key(:traversal_ids)
        end
      end

      context 'when traversal_id_search is available' do
        let(:guest_groups) { class_double(ApplicationRecord, exists?: true) }

        before do
          allow(::Search::Zoekt).to receive(:feature_available?)
            .with(:traversal_id_search, current_user, group_id: 1, project_id: [])
            .and_return(true)

          allow(auth).to receive(:get_groups_for_user)
            .with(hash_including(min_access_level: ::Gitlab::Access::GUEST))
            .and_return(guest_groups)

          allow(auth).to receive(:get_formatted_traversal_ids_for_groups)
            .with(guest_groups, anything)
            .and_return(['123-'])
        end

        it 'does not limit projects and uses traversal IDs' do
          result = builder.build

          auth_branch = result.find { |branch| branch.dig(:_context, :name) == 'public_and_internal_authorized_branch' }

          # Should have traversal ID filter when feature is available
          traversal_filter = auth_branch.dig(:and, :children, 2, :or, :children, 0)
          expect(traversal_filter).to have_key(:meta)
          expect(traversal_filter.dig(:meta, :key)).to eq('traversal_ids')
          expect(traversal_filter.dig(:meta, :value)).to eq('^123-')
        end
      end

      context 'when user is admin' do
        before do
          allow(current_user).to receive(:can_read_all_resources?).and_return(true)
          allow(::Search::Zoekt).to receive(:feature_available?)
            .with(:traversal_id_search, current_user, group_id: 1, project_id: [])
            .and_return(false)
        end

        it 'still applies project limit to admins' do
          result = builder.build

          # Admin should get admin branch (unrestricted visibility)
          # but project limiting still applies at the query level
          expect(result.first.dig(:_context, :name)).to eq('admin_branch')
        end
      end
    end

    describe 'project ID filtering optimization' do
      # These are integration tests using a real AuthorizationContext
      # (not the mocked auth from the outer describe block).
      let_it_be(:user) { create(:user) }
      let_it_be(:root_group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: root_group) }
      let_it_be(:outside_group) { create(:group) }

      # Projects inside the searched namespace
      let_it_be(:project_in_root) { create(:project, :private, namespace: root_group) }
      let_it_be(:project_in_sub) { create(:project, :private, namespace: sub_group) }
      # Project outside the searched namespace
      let_it_be(:project_outside) { create(:project, :private, namespace: outside_group) }

      let(:current_user) { user }
      let(:real_auth) { ::Search::AuthorizationContext.new(current_user) }
      let(:options) do
        {
          group_id: root_group.id,
          project_id: nil,
          search_level: :group,
          features: 'repository'
        }
      end

      # Use a separate builder with the real auth context, bypassing
      # the outer before block's stubs on the mocked auth.
      subject(:real_builder) { described_class.new(current_user, real_auth, options) }

      context 'when user has group-level access covering the searched namespace' do
        before_all do
          root_group.add_developer(user)
          outside_group.add_developer(user)
        end

        it 'excludes project IDs covered by group traversal_ids filters' do
          result = real_builder.build
          repo_ids = extract_repo_ids(result)

          expect(repo_ids).not_to include(project_in_root.id)
          expect(repo_ids).not_to include(project_in_sub.id)
        end

        it 'still includes traversal_ids filters for the group' do
          result = real_builder.build
          traversal_filters = extract_traversal_ids(result)

          expect(traversal_filters).not_to be_empty
        end
      end

      context 'when user has partial group coverage (subgroup member)' do
        before_all do
          sub_group.add_developer(user)
          project_outside.add_developer(user)
        end

        it 'excludes project IDs covered by subgroup traversal' do
          result = real_builder.build
          repo_ids = extract_repo_ids(result)

          # project_in_sub is covered by sub_group membership, should be excluded
          expect(repo_ids).not_to include(project_in_sub.id)
        end
      end

      context 'when user has no group access (project-only access)' do
        before_all do
          project_in_root.add_developer(user)
          project_outside.add_developer(user)
        end

        it 'includes project IDs in repo_ids' do
          result = real_builder.build
          repo_ids = extract_repo_ids(result)

          expect(repo_ids).to include(project_in_root.id)
        end
      end

      context 'when search_level is :global' do
        let(:options) do
          {
            group_id: nil,
            project_id: nil,
            search_level: :global,
            features: 'repository'
          }
        end

        before_all do
          root_group.add_developer(user)
        end

        it 'does not short-circuit project loading for global searches' do
          result = real_builder.build

          branch_contexts = result.map { |branch| branch.dig(:_context, :name) }
          expect(branch_contexts).to include('public_and_internal_branch')
        end
      end
    end
  end

  def extract_repo_ids(branches)
    branches.flat_map { |branch| extract_from_filter(branch, :repo_ids) }
  end

  def extract_traversal_ids(branches)
    branches.flat_map { |branch| extract_from_filter(branch, :traversal_meta) }
  end

  def extract_from_filter(filter, target)
    results = []

    case target
    when :repo_ids
      results.concat(filter[:repo_ids]) if filter[:repo_ids]
    when :traversal_meta
      results << filter.dig(:meta, :value) if filter[:meta] && filter.dig(:meta, :key) == 'traversal_ids'
    end

    children = filter.dig(:and, :children) || filter.dig(:or, :children) || []
    children.each { |child| results.concat(extract_from_filter(child, target)) }

    results
  end
end
