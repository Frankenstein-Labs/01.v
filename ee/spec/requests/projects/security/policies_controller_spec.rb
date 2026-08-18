# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::PoliciesController, type: :request, feature_category: :security_policy_management do
  let_it_be(:owner) { create(:user) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, security_policy_management_project: policy_management_project, project: project) }
  let_it_be(:policy) { build(:scan_execution_policy) }
  let_it_be(:type) { 'scan_execution_policy' }
  let_it_be(:index) { project_security_policies_url(project) }
  let_it_be(:new) { new_project_security_policy_url(project) }
  let_it_be(:feature_enabled) { true }

  let(:edit) { edit_project_security_policy_url(project, id: policy[:name], type: type) }

  before do
    project.add_developer(user)
    sign_in(user)
    stub_licensed_features(security_orchestration_policies: feature_enabled)
  end

  shared_context 'when feature is not licensed' do
    context 'when feature is not licensed' do
      let_it_be(:feature_enabled) { false }

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like "doesn't track govern usage event", 'security_policies'
    end
  end

  shared_examples 'an unauthorized user' do
    context 'when feature is licensed' do
      let_it_be(:feature_enabled) { true }

      it 'returns 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it_behaves_like "doesn't track govern usage event", 'security_policies'
    end

    include_context 'when feature is not licensed'
  end

  shared_examples 'an anonymous user' do
    context 'with private project' do
      let_it_be(:project) { create(:project, :private, namespace: owner.namespace) }

      it 'returns 302 and redirects user to the sign-in page' do
        request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with public project' do
      let_it_be(:project) { create(:project, :public, namespace: owner.namespace) }

      it 'returns 302 and redirects user to the sign-in page' do
        request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it_behaves_like "doesn't track govern usage event", 'security_policies'
  end

  describe 'GET #edit' do
    let(:request) { get edit }

    context 'with authorized user' do
      before do
        policy_management_project.add_developer(user)
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
        end
      end

      context 'when feature is licensed' do
        it 'renders the edit page' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:edit)

          app = Nokogiri::HTML.parse(response.body).at_css('div#js-policy-builder-app')

          expect(app.attributes['data-policy'].value).to eq(policy.to_json)
          expect(app.attributes['data-policy-type'].value).to eq(type)
        end

        context 'when approval policy type' do
          let_it_be(:type) { 'approval_policy' }
          let_it_be(:policy) { build(:approval_policy) }
          let_it_be(:group) { create(:group) }

          before do
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return({ approval_policy: [policy] }.to_yaml)
            end
          end

          it 'renders the edit page' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to render_template(:edit)

            app = Nokogiri::HTML.parse(response.body).at_css('div#js-policy-builder-app')

            expect(app['data-policy']).to eq(policy.to_json)
            expect(app['data-policy-type']).to eq(type)
          end
        end

        context 'when type is missing' do
          let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name]) }

          it 'redirects to #index' do
            request

            expect(response).to redirect_to(project_security_policies_path(project))
          end
        end

        context 'when type is invalid' do
          let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name], type: 'invalid') }

          it 'redirects to #index' do
            request

            expect(response).to redirect_to(project_security_policies_path(project))
          end
        end

        context 'when id does not exist' do
          let_it_be(:edit) { edit_project_security_policy_url(project, id: 'no-existing-policy', type: type) }

          it 'returns 404' do
            request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when there is no policy configuration' do
          let_it_be(:project) { create(:project, namespace: owner.namespace) }
          let_it_be(:policy_configuration) { nil }
          let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name], type: type) }

          it 'returns 404' do
            request

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when policy yaml file does not exist' do
          before do
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return({}.to_yaml)
            end
          end

          it 'redirects to project page' do
            request

            expect(response).to redirect_to(project_path(policy_management_project))
          end
        end

        context 'when policy yaml is invalid' do
          let_it_be(:policy) { { name: 'invalid' } }

          it 'redirects to policy file' do
            request

            expect(response).to redirect_to(
              project_blob_path(
                policy_management_project,
                File.join(policy_management_project.default_branch, ::Security::OrchestrationPolicyConfiguration::POLICY_PATH)
              )
            )
          end
        end

        it_behaves_like 'tracks govern usage event', 'security_policies'
      end

      include_context 'when feature is not licensed'
    end

    context 'with unauthorized user' do
      before do
        project.add_developer(user)
        policy_management_project.add_guest(user)
      end

      it_behaves_like 'an unauthorized user'
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like 'an anonymous user'
    end
  end

  describe 'GET #new' do
    subject(:request) { get new, params: { namespace_id: project.namespace, project_id: project } }

    context 'with authorized user' do
      context 'when feature is licensed' do
        it 'renders the new policy page' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:new)
        end

        it_behaves_like 'tracks govern usage event', 'security_policies'
      end

      include_context 'when feature is not licensed'
    end

    context 'with unauthorized user' do
      before do
        project.add_guest(user)
      end

      it_behaves_like 'an unauthorized user'
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like 'an anonymous user'
    end
  end

  describe 'GET #index' do
    subject(:request) { get index, params: { namespace_id: project.namespace, project_id: project } }

    context 'with authorized user' do
      context 'when feature is licensed' do
        it 'renders the policies page' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:index)
        end

        it 'pushes security_attributes_policy_scope feature flag' do
          request

          expect(response.body).to have_pushed_frontend_feature_flags(securityAttributesPolicyScope: true)
        end

        it_behaves_like 'tracks govern usage event', 'security_policies'
      end

      include_context 'when feature is not licensed'
    end

    context 'with unauthorized user' do
      before do
        project.add_reporter(user)
      end

      it_behaves_like 'an unauthorized user'
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like 'an anonymous user'
    end
  end

  describe 'GET #schema' do
    subject(:request) { get schema_project_security_policies_url(project) }

    context 'with authorized user' do
      context 'when feature is licensed' do
        let(:expected_json) do
          Gitlab::Json.parse(
            File.read(
              Rails.root.join(
                Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA_PATH
              )
            )
          )
        end

        it 'returns JSON schema' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq(expected_json)
        end

        it_behaves_like "doesn't track govern usage event", 'users_visiting_security_policies'
      end

      include_context 'when feature is not licensed'
    end

    context 'with unauthorized user' do
      before do
        project.add_guest(user)
      end

      it_behaves_like 'an unauthorized user'
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like 'an anonymous user'
    end
  end
end
