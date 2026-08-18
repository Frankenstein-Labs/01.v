# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::PoliciesController, type: :request, feature_category: :security_policy_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:policy_management_project) { create(:project, :small_repo, namespace: group) }
  let(:policy) { build(:scan_execution_policy) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace,
      security_policy_management_project: policy_management_project,
      namespace: group
    )
  end

  let_it_be(:feature_enabled) { true }

  before do
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

      it_behaves_like "doesn't track govern usage event", 'users_visiting_security_policies'
    end
  end

  shared_examples 'an unauthorized user' do
    context 'when feature is licensed' do
      let_it_be(:feature_enabled) { true }

      it 'returns 403' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it_behaves_like "doesn't track govern usage event", 'users_visiting_security_policies'
    end

    include_context 'when feature is not licensed'
  end

  shared_examples 'an anonymous user' do
    context 'with private group' do
      let_it_be(:group) { create(:group, :private) }

      it 'returns 302 and redirects user to the sign-in page' do
        request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with public group' do
      let_it_be(:group) { create(:group, :public) }

      it 'returns 302 and redirects user to the sign-in page' do
        request

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    it_behaves_like "doesn't track govern usage event", 'users_visiting_security_policies'
  end

  describe 'GET #edit' do
    let(:policy_id) { policy[:name] }
    let(:policy_type) { 'scan_execution_policy' }
    let(:edit) { edit_group_security_policy_url(group, id: policy_id, type: policy_type) }
    let(:request) { get edit }

    context 'with authorized user' do
      context 'when feature is licensed' do
        before do
          allow_next_instance_of(Repository) do |repository|
            allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
          end
        end

        it 'renders the edit page', :aggregate_failures do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:edit)

          app = Nokogiri::HTML.parse(response.body).at_css('div#js-group-policy-builder-app')
          yaml_path = "/#{policy_management_project.full_path}/-/blob/master/.gitlab/security-policies/policy.yml"

          expect(app.attributes['data-policy'].value).to eq(policy.to_json)
          expect(app.attributes['data-policy-type'].value).to eq('scan_execution_policy')
          expect(app.attributes['data-assigned-policy-project'].value).to eq({
            id: policy_management_project.to_gid.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main,
            policy_yaml_has_syntax_errors: 'false',
            policy_yaml_missing: 'false',
            policy_yaml_path: yaml_path
          }.to_json)
          expect(app.attributes['data-disable-scan-policy-update'].value).to eq('false')
          expect(app.attributes['data-policies-path'].value).to eq(
            "/groups/#{group.full_path}/-/security/policies"
          )
          expect(app.attributes['data-scan-policy-documentation-path'].value).to eq(
            '/help/user/application_security/policies/_index.md'
          )
          expect(app.attributes['data-namespace-path'].value).to eq(group.full_path)
          expect(app.attributes['data-namespace-id'].value).to eq(group.id.to_s)
        end

        context 'when approval policy type' do
          let(:policy) { build(:approval_policy) }
          let(:policy_type) { 'approval_policy' }

          before do
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return({ approval_policy: [policy] }.to_yaml)
            end
          end

          it 'renders the edit page' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to render_template(:edit)
          end
        end

        context 'when type is missing' do
          let(:policy_type) { nil }

          it 'redirects to #index', :aggregate_failures do
            request

            expect(response).to redirect_to(group_security_policies_path(group))
            expect(flash[:alert]).to eq(_('type parameter is missing and is required'))
          end
        end

        context 'when type is invalid' do
          let(:policy_type) { 'invalid' }

          it 'redirects to #index', :aggregate_failures do
            request

            expect(response).to redirect_to(group_security_policies_path(group))
            expect(flash[:alert]).to eq(_('Invalid policy type'))
          end
        end

        context 'when id does not exist' do
          let(:policy_id) { 'no-policy' }

          it 'returns 404' do
            request

            expect(response).to have_gitlab_http_status(:not_found)
          end

          context 'when there is no policy configuration' do
            let_it_be(:group) { create(:group) }
            let_it_be(:policy_configuration) { nil }

            it 'returns 404', :aggregate_failures do
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

            it 'redirects to project page', :aggregate_failures do
              request

              expect(response).to redirect_to(project_path(policy_management_project))
              expect(flash[:alert]).to eq(
                _("Policy management project does not have any policies in %{policy_path}") % {
                  policy_path: ::Security::OrchestrationPolicyConfiguration::POLICY_PATH
                })
            end
          end

          context 'when policy yaml is invalid' do
            let_it_be(:policy) { { name: 'invalid' } }

            it 'redirects to policy file', :aggregate_failures do
              request

              expect(flash[:alert]).to eq(_('Could not fetch policy because existing policy YAML is invalid'))
              expect(response).to redirect_to(
                project_blob_path(
                  policy_management_project,
                  File.join(
                    policy_management_project.default_branch,
                    ::Security::OrchestrationPolicyConfiguration::POLICY_PATH
                  )
                )
              )
            end
          end
        end

        it_behaves_like 'tracks govern usage event', 'security_policies' do
          let(:execute) { request }
        end
      end

      include_context 'when feature is not licensed'
      it_behaves_like "doesn't track govern usage event", 'security_policies'
    end

    context 'with unauthorized user' do
      before_all { group.add_reporter(user) }

      it_behaves_like 'an unauthorized user'
      it_behaves_like "doesn't track govern usage event", 'security_policies'
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like 'an anonymous user'
    end
  end

  describe 'GET #index' do
    subject(:request) { get index, params: { namespace_id: group } }

    let(:index) { group_security_policies_url(group) }

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
      before_all { group.add_reporter(user) }

      it_behaves_like "doesn't track govern usage event", 'security_policies'
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
    let(:request) { get schema_group_security_policies_url(group) }

    let(:expected_json) do
      Gitlab::Json.parse(
        File.read(
          Rails.root.join(
            Security::OrchestrationPolicyConfiguration::POLICY_SCHEMA_PATH
          )
        )
      )
    end

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
      before_all { group.add_guest(user) }

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
