# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupTemplatesFinder, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }

  let_it_be_with_reload(:group) do
    create(:group, name: 'root-group', project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
  end

  let_it_be_with_reload(:subgroup) do
    create(:group, parent: group, name: 'subgroup', project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
  end

  let_it_be(:subsubgroup) do
    create(
      :group, parent: subgroup, name: 'subsubgroup',
      project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS
    )
  end

  let_it_be(:other_group) { create(:group, name: 'other-group') }

  let_it_be(:template_group_root) { create(:group, parent: group, name: 'template-group-root') }
  let_it_be(:template_group_sub) { create(:group, parent: subgroup, name: 'template-group-sub') }
  let_it_be(:template_group_other) { create(:group, parent: other_group, name: 'template-group-other') }

  let_it_be(:template_project_root) { create(:project, namespace: template_group_root, name: 'template-root') }
  let_it_be(:template_project_sub) { create(:project, namespace: template_group_sub, name: 'template-sub') }
  let_it_be(:template_project_other) { create(:project, namespace: template_group_other, name: 'template-other') }

  let_it_be(:archived_project) { create(:project, :archived, namespace: template_group_root, name: 'archived') }
  let_it_be(:marked_for_deletion_project) do
    create(:project, :archived, namespace: template_group_root, name: 'deleted', marked_for_deletion_at: 1.day.ago)
  end

  subject(:execute) { described_class.new(user, group_id).execute }

  before_all do
    group.update!(custom_project_templates_group_id: template_group_root.id)
    subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
    other_group.update!(custom_project_templates_group_id: template_group_other.id)
  end

  before do
    stub_licensed_features(group_project_templates: true)
  end

  describe '#execute' do
    context 'when user is nil' do
      let(:user) { nil }
      let(:group_id) { group.id }

      it { is_expected.to eq(Project.none) }
    end

    context 'when group_id is nil' do
      let(:group_id) { nil }

      it { is_expected.to eq(Project.none) }
    end

    context 'when group_id is invalid' do
      let(:group_id) { non_existing_record_id }

      it { is_expected.to eq(Project.none) }
    end

    context 'when user cannot create projects in the group' do
      let(:group_id) { group.id }

      it { is_expected.to eq(Project.none) }
    end

    context 'when group_project_templates feature is not available' do
      let(:group_id) { group.id }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(group_project_templates: false)
      end

      it { is_expected.to eq(Project.none) }
    end

    context 'when user can create projects in the group' do
      before_all do
        group.add_developer(user)
      end

      context 'for a root group' do
        let(:group_id) { group.id }

        it 'only includes non-archived and projects not marked for deletion' do
          is_expected.to contain_exactly(template_project_root)
        end
      end

      context 'for a subgroup' do
        let(:group_id) { subgroup.id }

        before_all do
          subgroup.add_developer(user)
        end

        it { is_expected.to contain_exactly(template_project_root, template_project_sub) }

        context 'with multiple projects per template group' do
          let_it_be(:template_project_sub2) { create(:project, namespace: template_group_sub, name: 'template-sub2') }
          let_it_be(:template_project_root2) do
            create(:project, namespace: template_group_root, name: 'template-root2')
          end

          it 'orders by namespace_id first, then by id within each namespace' do
            result = execute.to_a

            expect(result.size).to eq(4)
            expect(result).to eq([template_project_root, template_project_root2, template_project_sub,
              template_project_sub2])

            expect(result[0].namespace_id).to be < result[2].namespace_id
            expect(result[0].id).to be < result[1].id
            expect(result[2].id).to be < result[3].id
          end
        end
      end

      context 'for a deeply nested group' do
        let(:group_id) { subsubgroup.id }

        before_all do
          subsubgroup.add_developer(user)
        end

        it 'returns template projects from all ancestors in the hierarchy' do
          is_expected.to contain_exactly(template_project_root, template_project_sub)
        end

        context 'when only some ancestors have templates configured' do
          let_it_be(:template_project_subsub) do
            template_group_subsub = create(:group, parent: subsubgroup, name: 'template-group-subsub')
            subsubgroup.update!(custom_project_templates_group_id: template_group_subsub.id)
            create(:project, namespace: template_group_subsub, name: 'template-project-subsub')
          end

          before_all do
            subgroup.update!(custom_project_templates_group_id: nil)
          end

          after(:all) do
            subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
          end

          it 'returns only template projects from ancestors with templates configured' do
            is_expected.to contain_exactly(template_project_root, template_project_subsub)
          end
        end
      end

      context 'when no ancestors have templates configured' do
        let(:group_id) { subsubgroup.id }

        before_all do
          group.update!(custom_project_templates_group_id: nil)
          subgroup.update!(custom_project_templates_group_id: nil)
        end

        after(:all) do
          group.update!(custom_project_templates_group_id: template_group_root.id)
          subgroup.update!(custom_project_templates_group_id: template_group_sub.id)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'with different permission levels' do
      let(:group_id) { group.id }

      context 'when user is a maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        it { is_expected.to contain_exactly(template_project_root) }
      end

      context 'when user is an owner' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to contain_exactly(template_project_root) }
      end

      context 'when user is a guest' do
        before_all do
          group.add_guest(user)
        end

        it { is_expected.to eq(Project.none) }
      end

      context 'when user is a reporter' do
        before_all do
          group.add_reporter(user)
        end

        it { is_expected.to eq(Project.none) }
      end
    end

    describe 'template visibility' do
      let_it_be(:visibility_user) { create(:user) }

      # Each row exercises one valid (root group visibility, subgroup visibility)
      # combination. For each group, `templates` lists the visibilities of the
      # projects created in its template group, and the expected sets list which
      # of those projects a given member should see, keyed by location (root/sub).
      #
      # A namespace cannot contain a project more visible than itself, so e.g. a
      # private subgroup only ever holds a private project.
      visibility_matrix = [
        {
          root_group: {
            visibility: :public,
            templates: [:public, :internal, :private]
          },
          subgroup: {
            visibility: :public,
            templates: [:public, :internal, :private]
          },
          templates_visible_to_root_member: {
            root: [:public, :internal, :private]
          },
          templates_visible_to_subgroup_member: {
            root: [:public, :internal],
            sub: [:public, :internal, :private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:public, :internal, :private],
            sub: [:public, :internal, :private]
          }
        },
        {
          root_group: {
            visibility: :public,
            templates: [:public, :internal, :private]
          },
          subgroup: {
            visibility: :internal,
            templates: [:internal, :private]
          },
          templates_visible_to_root_member: {
            root: [:public, :internal, :private]
          },
          templates_visible_to_subgroup_member: {
            root: [:public, :internal],
            sub: [:internal, :private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:public, :internal, :private],
            sub: [:internal, :private]
          }
        },
        {
          root_group: {
            visibility: :public,
            templates: [:public, :internal, :private]
          },
          subgroup: {
            visibility: :private,
            templates: [:private]
          },
          templates_visible_to_root_member: {
            root: [:public, :internal, :private]
          },
          templates_visible_to_subgroup_member: {
            root: [:public, :internal],
            sub: [:private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:public, :internal, :private],
            sub: [:private]
          }
        },
        {
          root_group: {
            visibility: :internal,
            templates: [:internal, :private]
          },
          subgroup: {
            visibility: :internal,
            templates: [:internal, :private]
          },
          templates_visible_to_root_member: {
            root: [:internal, :private]
          },
          templates_visible_to_subgroup_member: {
            root: [:internal],
            sub: [:internal, :private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:internal, :private],
            sub: [:internal, :private]
          }
        },
        {
          root_group: {
            visibility: :internal,
            templates: [:internal, :private]
          },
          subgroup: {
            visibility: :private,
            templates: [:private]
          },
          templates_visible_to_root_member: {
            root: [:internal, :private]
          },
          templates_visible_to_subgroup_member: {
            root: [:internal],
            sub: [:private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:internal, :private],
            sub: [:private]
          }
        },
        {
          root_group: {
            visibility: :private,
            templates: [:private]
          },
          subgroup: {
            visibility: :private,
            templates: [:private]
          },
          templates_visible_to_root_member: {
            root: [:private]
          },
          templates_visible_to_subgroup_member: {
            sub: [:private]
          },
          templates_visible_to_member_of_both_groups: {
            root: [:private],
            sub: [:private]
          }
        }
      ]

      visibility_matrix.each do |row|
        context "with a #{row[:root_group][:visibility]} root group and a #{row[:subgroup][:visibility]} subgroup" do
          # Resolve an expected set like `{ root: [:public], sub: [:private] }`
          # into the matching project records created in the `projects` hash below.
          define_method(:resolve_expected) do |expected|
            expected.flat_map { |location, visibilities| projects[location].values_at(*visibilities) }
          end

          let_it_be(:visibility_root_group) do
            create(:group, row[:root_group][:visibility],
              project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
          end

          let_it_be(:root_template_group) do
            create(:group, row[:root_group][:visibility], parent: visibility_root_group)
          end

          let_it_be(:visibility_subgroup) do
            create(:group, row[:subgroup][:visibility], parent: visibility_root_group,
              project_creation_level: ::Gitlab::Access::DEVELOPER_PROJECT_ACCESS)
          end

          let_it_be(:sub_template_group) { create(:group, row[:subgroup][:visibility], parent: visibility_subgroup) }

          let_it_be(:projects) do
            root = row[:root_group][:templates].index_with do |visibility|
              create(:project, :empty_repo, visibility, namespace: root_template_group)
            end

            sub = row[:subgroup][:templates].index_with do |visibility|
              create(:project, :empty_repo, visibility, namespace: sub_template_group)
            end

            { root: root, sub: sub }
          end

          let(:user) { visibility_user }

          let(:templates_visible_to_root_member) do
            resolve_expected(row[:templates_visible_to_root_member])
          end

          let(:templates_visible_to_subgroup_member) do
            resolve_expected(row[:templates_visible_to_subgroup_member])
          end

          let(:templates_visible_to_member_of_both_groups) do
            resolve_expected(row[:templates_visible_to_member_of_both_groups])
          end

          before_all do
            visibility_root_group.update!(custom_project_templates_group_id: root_template_group.id)
            visibility_subgroup.update!(custom_project_templates_group_id: sub_template_group.id)
          end

          context 'when group_id targets the root group' do
            let(:group_id) { visibility_root_group.id }

            context 'when user is not a member of either group' do
              it { is_expected.to eq(Project.none) }
            end

            context 'when user is a member of subgroup only' do
              before_all do
                visibility_subgroup.add_developer(visibility_user)
              end

              it { is_expected.to eq(Project.none) }
            end

            context 'when user is a member of root group only' do
              before_all do
                visibility_root_group.add_developer(visibility_user)
              end

              it 'sees only root template group projects, not subgroup template projects' do
                is_expected.to match_array(templates_visible_to_root_member)
              end
            end

            context 'when user is a member of both groups' do
              before_all do
                visibility_root_group.add_developer(visibility_user)
                visibility_subgroup.add_developer(visibility_user)
              end

              it 'sees only root template group projects, not subgroup template projects' do
                is_expected.to match_array(templates_visible_to_root_member)
              end
            end
          end

          context 'when group_id targets the subgroup' do
            let(:group_id) { visibility_subgroup.id }

            context 'when user is not a member of either group' do
              it { is_expected.to eq(Project.none) }
            end

            context 'when user is a member of subgroup only' do
              before_all do
                visibility_subgroup.add_developer(visibility_user)
              end

              it 'sees projects visible to a subgroup member' do
                is_expected.to match_array(templates_visible_to_subgroup_member)
              end
            end

            context 'when user is a member of root group only' do
              before_all do
                visibility_root_group.add_developer(visibility_user)
              end

              it 'sees all projects via inherited membership' do
                is_expected.to match_array(templates_visible_to_member_of_both_groups)
              end
            end

            context 'when user is a member of both groups' do
              before_all do
                visibility_root_group.add_developer(visibility_user)
                visibility_subgroup.add_developer(visibility_user)
              end

              it 'sees all projects from both template groups' do
                is_expected.to match_array(templates_visible_to_member_of_both_groups)
              end
            end
          end
        end
      end
    end

    describe 'Query Performance' do
      it 'avoids N+1 database queries when additional groups and projects are present',
        :request_store, :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          described_class.new(user, group.id).execute
        end

        create(:project, :empty_repo, namespace: template_group_root)
        create(:project, :empty_repo, namespace: template_group_sub)

        expect { described_class.new(user, subgroup.id).execute }.to issue_same_number_of_queries_as(control)
      end
    end
  end
end
