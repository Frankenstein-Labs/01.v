# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MembersFinder, feature_category: :groups_and_projects do
  let_it_be(:group) { create :group }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }
  let(:params) { {} }
  let(:options) { {} }

  subject(:members) { described_class.new(project, create(:user), params: params).execute(**options) }

  describe '.execute' do
    context 'when including invited group relations' do
      let(:options) { { include_relations: [:invited_groups] } }

      context 'when invited group member is assigned custom role in invited group', :saas do
        let_it_be(:invited_group) { create(:group) }
        let_it_be(:custom_role) { create(:member_role, :maintainer, :admin_protected_branch, namespace: invited_group) }
        let_it_be(:invited_group_member) do
          create(:group_member, :maintainer, member_role: custom_role, group: invited_group)
        end

        let(:project_group_link) { create(:project_group_link, :guest, project: project, group: invited_group) }

        before do
          enable_namespace_license_check!
          stub_licensed_features(custom_roles: true)
          project_group_link
        end

        context 'and inviting project does not have custom roles feature' do
          it 'invited group members should not have member_role_id' do
            member = members.find_by(user_id: invited_group_member.user_id)

            expect(member.member_role_id).to be_nil
            expect(member.access_level).to eq(Gitlab::Access::GUEST)
          end
        end

        context 'and inviting project does have custom roles feature' do
          before do
            create(:gitlab_subscription, :ultimate, namespace: project.root_namespace)
          end

          it 'invited group members should not have member_role_id' do
            member = members.find_by(user_id: invited_group_member.user_id)

            expect(member.member_role_id).to be_nil
          end

          context 'when inviting project specified a custom role' do
            let_it_be(:custom_role_2) { create(:member_role, :developer, :archive_project, namespace: group) }
            let(:project_group_link) do
              create(:project_group_link, project: project, group: invited_group, member_role_id: custom_role_2)
            end

            it 'invited group members should not have member_role_id' do
              member = members.find_by(user_id: invited_group_member.user_id)

              expect(member.member_role_id).to be_nil
            end
          end
        end
      end
    end

    context 'when filtering by max_role' do
      let_it_be(:member_role) { create(:member_role, :guest, namespace: group) }
      let_it_be(:member_without_custom_role) { create(:project_member, :guest, project: project) }
      let_it_be(:member_with_custom_role) do
        create(:project_member, :guest, project: project, member_role: member_role)
      end

      let(:params) { { max_role: max_role } }

      context 'when filtering by custom role ID' do
        context 'and project has custom roles feature' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          describe 'provided member role ID is incorrect' do
            using RSpec::Parameterized::TableSyntax

            where(:max_role) { [nil, '', lazy { "xcustom-#{member_role.id}" }, lazy { "custom-#{member_role.id}x" }] }

            with_them do
              it { is_expected.to match_array(project.members) }
            end
          end

          describe 'none of the members have the provided member role ID' do
            let(:max_role) { "custom-#{non_existing_record_id}" }

            it { is_expected.to be_empty }
          end

          describe 'one of the members has the provided member role ID' do
            let(:max_role) { "custom-#{member_role.id}" }

            it { is_expected.to contain_exactly(member_with_custom_role) }
          end
        end
      end
    end
  end
end
