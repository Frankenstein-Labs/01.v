# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_dependency custom role', feature_category: :system_access do
  let_it_be(:project) { create(:project, :repository, :in_group, :security_and_compliance_enabled) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, :with_dependency_list_report, project: project) }

  before do
    stub_licensed_features(
      dependency_scanning: true,
      custom_roles: true,
      security_dashboard: true
    )

    sign_in(user)
  end

  describe Projects::DependenciesController do
    let_it_be(:user) { create(:user) }
    let_it_be(:role) { create(:member_role, :guest, namespace: project.group, read_dependency: true) }
    let_it_be(:member) do
      create(:project_member, :guest, member_role: role, user: user, project: project)
    end

    describe "#index" do
      it 'user has access via a custom role' do
        get project_dependencies_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe "#licenses" do
      it 'user has access via a custom role' do
        get licenses_project_dependencies_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe Groups::DependenciesController do
    let_it_be(:user) { create(:user) }
    let_it_be(:role) { create(:member_role, :guest, namespace: project.group, read_dependency: true) }
    let_it_be(:member) do
      create(:group_member, :guest, member_role: role, user: user, source: project.group)
    end

    describe "#index" do
      it 'user has access via a custom role' do
        get group_dependencies_path(project.group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe "#licenses" do
      it 'user has access via a custom role' do
        get licenses_group_dependencies_path(group_id: project.group.full_path)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
