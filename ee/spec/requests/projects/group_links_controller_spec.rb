# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project group links', :aggregate_failures, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }
  let_it_be(:member_role) { create(:member_role, namespace: project.namespace) }
  let_it_be(:new_member_role) { create(:member_role, namespace: project.namespace) }

  let_it_be(:project_group_link) do
    create(:project_group_link, project: project, member_role: member_role)
  end

  subject(:send_request) do
    put namespace_project_group_link_path(
      namespace_id: project.namespace,
      project_id: project,
      id: project_group_link,
      params: params
    )
  end

  before do
    stub_licensed_features(custom_roles: true)

    login_as(user)
  end

  describe 'PUT /:namespace/:project/-/group_links/:id' do
    context 'with member_role_id param', :saas do
      let(:params) do
        { group_link: { group_access: new_member_role.base_access_level, member_role_id: new_member_role.id } }
      end

      it 'updates the link\'s member_role_id' do
        expect { send_request }.to change {
          project_group_link.reload.member_role_id
        }.from(member_role.id).to(new_member_role.id)
      end
    end
  end
end
