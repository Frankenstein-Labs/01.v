# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_compliance_dashboard custom role', feature_category: :compliance_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:role) { create(:member_role, :guest, :read_compliance_dashboard, namespace: group) }
  let_it_be(:membership) do
    create(:group_member, :guest, member_role: role, user: current_user, group: group)
  end

  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  before do
    stub_licensed_features(compliance_features.merge(custom_roles: true))

    sign_in(current_user)
  end

  describe Groups::Security::ComplianceDashboardsController do
    let(:compliance_features) do
      {
        custom_compliance_frameworks: true,
        evaluate_group_level_compliance_pipeline: true,
        group_level_compliance_dashboard: true,
        group_level_compliance_adherence_report: true,
        group_level_compliance_violations_report: true
      }
    end

    describe "#show" do
      it 'user can see compliance dashboard' do
        get group_security_compliance_dashboard_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end
  end

  describe Projects::Security::ComplianceDashboardsController do
    let(:compliance_features) do
      {
        compliance_framework: true,
        project_level_compliance_dashboard: true,
        project_level_compliance_adherence_report: true,
        project_level_compliance_violations_report: true
      }
    end

    describe "#show" do
      it 'user can see compliance dashboard' do
        get project_security_compliance_dashboard_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end
  end
end
