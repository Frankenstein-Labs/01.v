# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Export::DetailedDataService, feature_category: :system_access do
  include_context 'with group members shared context'

  let(:current_user) { users[0] }
  let(:requested_group) { group }

  subject(:export) { described_class.new(container: requested_group, current_user: current_user).execute }

  shared_examples 'not available' do
    it 'returns a failed response' do
      response = export

      expect(response).not_to be_success
      expect(response.message).to eq('Not available')
    end
  end

  describe '#execute' do
    context 'when unlicensed' do
      before do
        stub_licensed_features(export_user_permissions: false)
      end

      it_behaves_like 'not available'
    end

    context 'when licensed' do
      before do
        stub_licensed_features(export_user_permissions: true)
      end

      context 'when current_user is a group maintainer' do
        let(:current_user) { users[1] }

        it_behaves_like 'not available'
      end

      context 'when current user is a group owner' do
        shared_examples 'exporting correct data' do
          it 'is successful' do
            expect(export).to be_success
          end

          it 'returns correct data' do
            headers = ['Name', 'Username', 'Email', 'Path', 'Group or project name', 'Type', 'Role', 'Role type',
              'Membership type', 'Membership status', 'Membership source', 'Access granted', 'Access expiration',
              'Last activity']

            expect(data).to match_array([headers] + expected_result)
          end
        end

        let(:data) { CSV.parse(export.payload) }
        let(:group_members) do
          [
            row_data(0, group, group, group_owner_1),
            row_data(1, group, group, group_maintainer_2),
            row_data(2, group, group, group_developer_3)
          ]
        end

        let(:group_project_1_members) do
          [
            row_data(0, group_project_1, group, group_owner_1),
            row_data(1, group_project_1, group, group_maintainer_2),
            row_data(2, group_project_1, group, group_developer_3),
            row_data(4, group_project_1, group_project_1, group_project_1_owner_5)
          ]
        end

        let(:group_project_2_members) do
          [
            row_data(0, group_project_2, group, group_owner_1),
            row_data(1, group_project_2, group, group_maintainer_2),
            row_data(2, group_project_2, group, group_developer_3),
            row_data(5, group_project_2, group_project_2, group_project_2_owner_6)
          ]
        end

        let(:sub_group_1_members) do
          [
            row_data(1, sub_group_1, sub_group_1, sub_group_1_owner_2),
            row_data(0, sub_group_1, group, group_owner_1),
            row_data(2, sub_group_1,  group, group_developer_3),
            row_data(4, sub_group_1,  shared_group, shared_maintainer_5),
            row_data(5, sub_group_1,  shared_group, shared_maintainer_6)
          ]
        end

        let(:sub_group_1_project_members) do
          [
            row_data(1, sub_group_1_project, sub_group_1, sub_group_1_owner_2),
            row_data(0, sub_group_1_project, group, group_owner_1),
            row_data(2, sub_group_1_project, group, group_developer_3),
            row_data(4, sub_group_1_project, shared_group, shared_maintainer_5),
            row_data(5, sub_group_1_project, shared_group, shared_maintainer_6),
            row_data(3, sub_group_1_project, sub_group_1_project, sub_group_1_project_maintainer_4)
          ]
        end

        let(:sub_group_2_members) do
          [
            row_data(0, sub_group_2, group, group_owner_1),
            row_data(1, sub_group_2, group, group_maintainer_2),
            row_data(2, sub_group_2, group, group_developer_3)
          ]
        end

        let(:sub_sub_group_1_members) do
          [
            row_data(3, sub_sub_group_1, sub_sub_group_1, sub_sub_group_owner_4),
            row_data(4, sub_sub_group_1, sub_sub_group_1, sub_sub_group_owner_5),
            row_data(0, sub_sub_group_1, group, group_owner_1),
            row_data(1, sub_sub_group_1, sub_group_1, sub_group_1_owner_2),
            row_data(2, sub_sub_group_1, group, group_developer_3),
            row_data(5, sub_sub_group_1, shared_group, shared_maintainer_6),
            row_data(nil, sub_sub_group_1, sub_sub_group_1, sub_sub_group_invited_developer)
          ]
        end

        let(:sub_sub_sub_group_1_members) do
          [
            row_data(0, sub_sub_sub_group_1, group, group_owner_1),
            row_data(1, sub_sub_sub_group_1, sub_group_1, sub_group_1_owner_2),
            row_data(2, sub_sub_sub_group_1, group, group_developer_3),
            row_data(3, sub_sub_sub_group_1, sub_sub_group_1, sub_sub_group_owner_4),
            row_data(4, sub_sub_sub_group_1, sub_sub_group_1, sub_sub_group_owner_5),
            row_data(5, sub_sub_sub_group_1, shared_group, shared_maintainer_6),
            row_data(nil, sub_sub_sub_group_1, sub_sub_group_1, sub_sub_group_invited_developer)
          ]
        end

        def get_membershipable_type(namespace)
          if namespace.is_a?(Project)
            'Project'
          elsif namespace.is_a?(Group) && namespace.parent_id
            'Sub Group'
          else
            'Group'
          end
        end

        def get_membership_type(namespace, source)
          if source == shared_group
            'shared'
          elsif namespace == source
            'direct'
          else
            'inherited'
          end
        end

        def row_data(user_id, namespace, source, member)
          user = users[user_id] if user_id.present?
          role_name = source == shared_group ? 'Reporter' : member.human_access
          role_type = member.member_role ? 'custom' : 'default'
          member_status = member.pending? ? 'pending' : 'approved'

          [user&.name, user&.username, user&.email || member.invite_email, namespace.full_path, namespace.name,
            get_membershipable_type(namespace), role_name, role_type, get_membership_type(namespace, source),
            member_status, source.full_path, member.created_at.iso8601, nil,
            member.reload.user&.last_activity_on&.iso8601]
        end

        context 'when members_permissions_detailed_export feature flag is disabled' do
          before do
            stub_feature_flags(members_permissions_detailed_export: false)
          end

          it_behaves_like 'not available'
        end

        context 'when members_permissions_detailed_export feature flag is enabled' do
          before do
            stub_feature_flags(members_permissions_detailed_export: true)
          end

          context 'for group' do
            let(:requested_group) { group }
            let(:expected_result) do
              group_members + sub_group_1_members + sub_group_2_members +
                sub_sub_group_1_members + sub_sub_sub_group_1_members +
                group_project_1_members + group_project_2_members + sub_group_1_project_members
            end

            it_behaves_like 'exporting correct data'

            describe 'avoiding N+1 queries' do
              it 'when new memberships for existing entities are created' do
                count = ActiveRecord::QueryRecorder.new { export }

                create(:group_member, :owner, group: requested_group, user: create(:user))
                create(:project_member, :owner, project: group_project_1, user: create(:user))

                expect { described_class.new(container: requested_group, current_user: current_user).execute }
                  .not_to exceed_query_limit(count)
              end

              it 'when new memberships for a new group is added' do
                count = ActiveRecord::QueryRecorder.new { export }

                new_group = create(:group, parent: requested_group)
                create(:group_member, :owner, group: new_group, user: users[5])

                # additional queries: namespaces 2x, organizations + organization_users, routes 2x,
                # users, projects, access levels, members
                # some of the queries are "hidden" in GroupMembersFinder
                expect { described_class.new(container: requested_group, current_user: current_user).execute }
                  .not_to exceed_query_limit(count).with_threshold(10)
              end

              it 'when new memberships for a new project is added',
                quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/21817' do
                count = ActiveRecord::QueryRecorder.new { export }

                new_project = create(:project, group: requested_group)
                create(:project_member, :owner, project: new_project, user: users[5])

                # additional queries: users, routes 2x, project + authorizations, members
                # most of the queries are "hidden" in MembersFinder
                expect { described_class.new(container: requested_group, current_user: current_user).execute }
                  .not_to exceed_query_limit(count).with_threshold(6)
              end
            end
          end

          context 'for subgroup' do
            let(:requested_group) { sub_group_1 }
            let(:expected_result) do
              sub_group_1_members + sub_sub_group_1_members + sub_sub_sub_group_1_members +
                sub_group_1_project_members
            end

            it_behaves_like 'exporting correct data'
          end

          context 'for sub_sub_group' do
            let(:requested_group) { sub_sub_group_1 }
            let(:expected_result) { sub_sub_group_1_members + sub_sub_sub_group_1_members }

            it_behaves_like 'exporting correct data'
          end

          context 'for sub_sub_sub_group_1' do
            let(:requested_group) { sub_sub_sub_group_1 }
            let(:expected_result) { sub_sub_sub_group_1_members }

            it_behaves_like 'exporting correct data'
          end
        end
      end
    end
  end
end
