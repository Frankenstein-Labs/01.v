# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Groups::Security::ComplianceDashboard::ExportsController, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_owner user
  end

  describe 'GET #compliance_status_report' do
    before do
      stub_licensed_features(group_level_compliance_dashboard: true)
      sign_in(user)
    end

    it 'triggers export and redirects' do
      expect_next_instance_of(
        ::ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::ExportService) do |service|
        expect(service).to receive(:email_export).and_return(ServiceResponse.success)
      end

      get :compliance_status_report, params: { group_id: group.to_param }, format: :csv

      expect(response).to redirect_to(group_security_compliance_dashboard_path(group))
      expect(flash[:notice]).to eq('After the report is generated, an email will be sent with the report attached.')
    end
  end

  describe 'GET #violations_report' do
    before do
      stub_licensed_features(group_level_compliance_dashboard: true)
      sign_in(user)
    end

    it 'triggers export and redirects' do
      expect_next_instance_of(::ComplianceManagement::Groups::ComplianceViolations::ExportService) do |service|
        expect(service).to receive(:email_export).and_return(ServiceResponse.success)
      end

      get :violations_report, params: { group_id: group.to_param }, format: :csv

      expect(response).to redirect_to(group_security_compliance_dashboard_path(group))
      expect(flash[:notice]).to eq('After the report is generated, an email will be sent with the report attached.')
    end

    context 'when user does not have permission' do
      let(:unauthorized_user) { create(:user) }

      before do
        sign_in(unauthorized_user)
      end

      it 'returns 404' do
        get :violations_report, params: { group_id: group.to_param }, format: :csv

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
