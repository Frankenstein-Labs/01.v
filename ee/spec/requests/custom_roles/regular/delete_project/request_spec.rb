# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with remove_project custom role', feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe ProjectsController do
    let_it_be(:role) { create(:member_role, :guest, namespace: project.group, remove_project: true) }
    let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

    describe "#edit" do
      it 'user has access via a custom role' do
        get edit_project_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:edit)
      end
    end

    describe "#destroy" do
      it 'user has access via a custom role' do
        delete project_path(project)

        expect(project.reload).to be_self_deletion_scheduled
        expect(response).to have_gitlab_http_status(:found)
      end
    end
  end
end
