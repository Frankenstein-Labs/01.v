# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Project, feature_category: :permissions do
  subject(:project_authorization) { described_class.new(user, scope: scope) }

  let(:scope) { ::Project.all }

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: root_group) }
  let_it_be(:child_group) { create(:group, parent: group) }

  let_it_be(:root_project) { create(:project, group: root_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:child_project) { create(:project, group: child_group) }
  let_it_be(:other_projects) { create_list(:project, 3) }

  let_it_be(:admin_runners_role) { create(:member_role, :guest, :admin_runners, namespace: root_group) }
  let_it_be(:admin_vulnerability_role) { create(:member_role, :guest, :admin_vulnerability, namespace: root_group) }
  let_it_be(:archive_project_role) { create(:member_role, :maintainer, :archive_project, namespace: root_group) }
  let_it_be(:read_dependency_role) { create(:member_role, :guest, :read_dependency, namespace: root_group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe "#permitted" do
    subject(:permitted) { project_authorization.permitted }

    context 'when authorized for different permissions at different levels in the group hierarchy' do
      let_it_be(:memberships) do
        [
          [admin_runners_role, root_group],
          [admin_vulnerability_role, group],
          [read_dependency_role, child_group],
          [archive_project_role, child_project]
        ]
      end

      before_all do
        memberships.each do |(role, source)|
          if source.is_a?(::Group)
            create(:group_member, :guest, member_role: role, user: user, source: source)
          else
            create(:project_member, :guest, member_role: role, user: user, source: source)
          end
        end
      end

      it 'includes other projects that the current user is not permitted to' do
        other_projects.each do |other_project|
          is_expected.to include(other_project.id => match_array([]))
        end
      end

      it { is_expected.to include(root_project.id => include(:admin_runners)) }
      it { is_expected.to include(project.id => include(:admin_runners, :admin_vulnerability)) }

      it 'includes direct and inherited permissions' do
        is_expected.to include(child_project.id => include(
          :admin_runners,
          :admin_vulnerability,
          :read_dependency,
          :archive_project
        ))
      end
    end
  end
end
