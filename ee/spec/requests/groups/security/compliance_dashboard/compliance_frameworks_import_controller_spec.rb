# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::ComplianceDashboard::ComplianceFrameworksImportController, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:file) { fixture_file_upload('compliance_dashboard/soc2_template.json') }

  before do
    login_as user
  end

  describe 'POST /groups/:group_id/-/security/compliance_frameworks/import' do
    subject(:import_frameworks) do
      post import_group_security_compliance_frameworks_path(group, format: :json), params: { framework_file: file }
    end

    context 'when user does not have access to import frameworks' do
      it 'renders not found' do
        import_frameworks

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has access to import frameworks' do
      before_all do
        group.add_owner user
      end

      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      context 'with valid JSON file' do
        it 'creates the freamework' do
          expect { import_frameworks }.to change { ComplianceManagement::Framework.count }.by(1)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq(
            'status' => 'success',
            'framework_id' => ComplianceManagement::Framework.last.id
          )
        end

        it 'sends back model errors properly' do
          expect { import_frameworks }.to change { ComplianceManagement::Framework.count }.by(1)
          expect do
            post import_group_security_compliance_frameworks_path(group, format: :json),
              params: { framework_file: file }
          end.not_to change { ComplianceManagement::Framework.count }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq(
            'status' => 'error',
            'message' => 'Failed to create framework, Name has already been taken'
          )
        end

        context 'with valid framework but invalid controls' do
          let(:file) { fixture_file_upload('compliance_dashboard/invalid_controls.json') }

          it 'sends back control issues' do
            import_frameworks

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response['status']).to eq('success')
            expect(json_response['message']).to match(/control errors: 'hello world' is not a valid name/)
            expect(json_response['message']).to match(/control errors: 'blah' is not a valid control_type/)
            expect(json_response['framework_id']).to eq(ComplianceManagement::Framework.last.id)
          end
        end
      end

      context 'with invalid file type' do
        let(:file) { fixture_file_upload('compliance_dashboard/invalid_file.txt') }

        it 'redirects with error message' do
          import_frameworks

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['status']).to eq('error')
          expect(json_response['message']).to eq('Invalid file format')
        end
      end

      context 'with malformed JSON file' do
        let(:file) { fixture_file_upload('compliance_dashboard/malformed.json') }

        it 'redirects with error message' do
          import_frameworks

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['status']).to eq('error')
          expect(json_response['message']).to eq('Invalid file format')
        end
      end

      context 'without file' do
        subject(:import_frameworks) do
          post import_group_security_compliance_frameworks_path(group), params: {}
        end

        it 'redirects with error message' do
          import_frameworks

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['status']).to eq('error')
          expect(json_response['message']).to eq('No template file provided')
        end
      end
    end
  end
end
