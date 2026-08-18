# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Security::CompliancePolicySettings, feature_category: :security_policy_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- API manages self-managed instance-wide setting. Support for organization-level settings will be added later.
  let(:params) { { csp_namespace_id: nil } }

  shared_examples 'requires admin authentication' do |verb|
    context 'when user is not authenticated' do
      it 'returns 401' do
        public_send(verb, api(path, nil))

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user is not an admin' do
      it 'returns 403' do
        public_send(verb, api(path, user))

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples 'requires security_orchestration_policies license' do |verb|
    before do
      stub_licensed_features(security_orchestration_policies: false)
    end

    it 'returns 403' do
      public_send(verb, api(path, admin, admin_mode: true), params: params)

      expect(response).to have_gitlab_http_status(:forbidden)
      expect(json_response['message'])
        .to eq('403 Forbidden - security_orchestration_policies license feature not available')
    end
  end

  describe 'GET /admin/security/compliance_policy_settings' do
    let(:path) { '/admin/security/compliance_policy_settings' }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    it_behaves_like 'GET request permissions for admin mode'
    it_behaves_like 'requires admin authentication', :get
    it_behaves_like 'requires security_orchestration_policies license', :get
    it_behaves_like 'authorizing granular token permissions', :read_compliance_policy_setting do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    context 'when all requirements are met' do
      let!(:policy_setting) { Security::PolicySetting.in_organization(default_organization) }

      before do
        policy_setting.update!(csp_namespace_id: group.id)
      end

      it 'returns security policy settings' do
        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({
          'csp_namespace_id' => group.id
        })
      end

      context 'when csp_namespace_id is nil' do
        before do
          policy_setting.update_column(:csp_namespace_id, nil)
        end

        it 'returns null for csp_namespace_id' do
          get api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'csp_namespace_id' => nil
          })
        end
      end
    end
  end

  describe 'PUT /admin/security/compliance_policy_settings' do
    let(:path) { '/admin/security/compliance_policy_settings' }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    it_behaves_like 'PUT request permissions for admin mode'
    it_behaves_like 'requires admin authentication', :put
    it_behaves_like 'requires security_orchestration_policies license', :put
    it_behaves_like 'authorizing granular token permissions', :update_compliance_policy_setting do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(path, personal_access_token: pat), params: { csp_namespace_id: group.id } }
    end

    context 'when all requirements are met' do
      let!(:policy_setting) { Security::PolicySetting.in_organization(default_organization) }

      context 'with valid csp_namespace_id' do
        it 'updates the csp_namespace_id' do
          put api(path, admin, admin_mode: true), params: { csp_namespace_id: group.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'csp_namespace_id' => group.id
          })
          expect(policy_setting.reload.csp_namespace_id).to eq(group.id)
        end
      end

      context 'with nil csp_namespace_id' do
        before do
          policy_setting.update_column(:csp_namespace_id, group.id)
        end

        it 'clears the csp_namespace_id' do
          put api(path, admin, admin_mode: true), params: { csp_namespace_id: nil }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'csp_namespace_id' => nil
          })
          expect(policy_setting.reload.csp_namespace_id).to be_nil
        end
      end

      describe 'invalid namespace IDs' do
        context 'with invalid csp_namespace_id' do
          let_it_be(:project_namespace) { create(:project).project_namespace }

          it 'returns validation errors' do
            put api(path, admin, admin_mode: true), params: { csp_namespace_id: project_namespace.id }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include('must be a group')
          end
        end

        context 'with user namespace' do
          let_it_be(:user_namespace) { create(:user_namespace) }

          it 'returns validation errors' do
            put api(path, admin, admin_mode: true), params: { csp_namespace_id: user_namespace.id }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include('CSP namespace must be a group')
          end
        end

        context 'when group is not top-level' do
          let_it_be(:subgroup) { create(:group, parent: group) }

          it 'returns validation errors' do
            put api(path, admin, admin_mode: true), params: { csp_namespace_id: subgroup.id }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include('CSP namespace must be a top level Group')
          end
        end
      end

      context 'with non-existent csp_namespace_id' do
        it 'returns validation errors' do
          put api(path, admin, admin_mode: true), params: { csp_namespace_id: non_existing_record_id }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to be_present
        end
      end

      context 'without parameters' do
        before do
          put api(path, admin, admin_mode: true), params: { csp_namespace_id: group.id }
        end

        it 'returns error and does not change the attribute' do
          expect { put api(path, admin, admin_mode: true) }.not_to change { policy_setting.reload.csp_namespace_id }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq('csp_namespace_id is missing')
        end
      end
    end
  end
end
