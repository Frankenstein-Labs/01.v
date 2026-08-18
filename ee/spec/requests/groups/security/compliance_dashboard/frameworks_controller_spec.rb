# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups::Security::ComplianceDashboard::Frameworks', feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:framework) do
    create(:compliance_framework, namespace: group).tap do |framework|
      requirement = create(:compliance_requirement, framework: framework)
      create(:compliance_requirements_control, compliance_requirement: requirement)
    end
  end

  before do
    sign_in(user)
  end

  describe 'GET /groups/:group_id/security/compliance_dashboard/frameworks/:id' do
    def make_request
      get group_security_compliance_dashboard_framework_path(group, framework), as: :json
    end

    context 'when compliance dashboard feature is disabled' do
      it 'returns not found' do
        make_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when compliance dashboard feature is enabled' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      context 'and user is not allowed to access group compliance dashboard' do
        it 'returns not found' do
          make_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'and user is allowed to access group compliance dashboard' do
        before_all do
          group.add_owner(user)
        end

        it 'returns success' do
          make_request

          expect(response).to have_gitlab_http_status(:success)
        end

        context 'when framework does not exist' do
          it 'returns not found' do
            get group_security_compliance_dashboard_framework_path(group, non_existing_record_id), as: :json

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when framework name contains special characters' do
          let(:framework) do
            create(:compliance_framework, name: 'Test & Framework (2024)', namespace: group).tap do |framework|
              requirement = create(:compliance_requirement, framework: framework)
              create(:compliance_requirements_control, compliance_requirement: requirement)
            end
          end

          it 'sanitizes the filename correctly' do
            make_request

            expected_filename = "compliance-framework-test-framework-2024-#{framework.id}.json"
            expect(response.headers['Content-Disposition']).to match(/attachment; filename="#{expected_filename}"/)
          end
        end

        context 'when export is successful' do
          let(:export_service) { instance_double(ComplianceManagement::Frameworks::JsonExportService) }
          let(:export_payload) { { data: 'exported_framework_data' }.to_json }

          before do
            allow(ComplianceManagement::Frameworks::JsonExportService)
              .to receive(:new)
              .with(user: user, group: group, framework: framework)
              .and_return(export_service)
            allow(export_service).to receive(:execute).and_return(ServiceResponse.success(payload: export_payload))
          end

          it 'returns success with exported data' do
            make_request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq(::Gitlab::Json.parse(export_payload))
          end

          it 'sets the correct filename in Content-Disposition header' do
            make_request

            expected_filename = "compliance-framework-#{framework.name.parameterize}-#{framework.id}.json"
            expect(response.headers['Content-Disposition']).to match(/attachment; filename="#{expected_filename}"/)
          end
        end

        context 'when export fails' do
          let(:export_service) { instance_double(ComplianceManagement::Frameworks::JsonExportService) }

          before do
            allow(ComplianceManagement::Frameworks::JsonExportService)
              .to receive(:new)
              .with(user: user, group: group, framework: framework)
              .and_return(export_service)
            allow(export_service)
              .to receive(:execute)
              .and_return(ServiceResponse.error(message: 'Failed to generate export'))
          end

          it 'returns error response' do
            make_request

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response).to eq({ 'error' => 'Failed to generate export' })
          end
        end

        context 'when trying to access framework from another group' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:other_framework) { create(:compliance_framework, namespace: other_group) }

          before_all do
            other_group.add_owner(user)
          end

          it 'returns not found' do
            get group_security_compliance_dashboard_framework_path(group, other_framework), as: :json

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
