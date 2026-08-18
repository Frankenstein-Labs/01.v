# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectPushRule, 'ProjectPushRule', :api, feature_category: :source_code_management do
  include ApiHelpers

  let_it_be(:project) { create(:project) }

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let_it_be(:attributes, freeze: false) do
    {
      author_email_regex: '^[A-Za-z0-9.]+@gitlab.com$',
      commit_committer_check: true,
      commit_committer_name_check: true,
      commit_message_negative_regex: '[x+]',
      commit_message_regex: '[a-zA-Z]',
      deny_delete_tag: false,
      max_file_size: 100,
      member_check: false,
      prevent_secrets: true,
      reject_unsigned_commits: true,
      reject_non_dco_commits: true
    }
  end

  let(:push_rules_enabled) { true }
  let(:ccc_enabled) { true }
  let(:ccnc_enabled) { true }
  let(:ruc_enabled) { true }
  let(:rnd_enabled) { true }

  before do
    stub_licensed_features(
      push_rules: push_rules_enabled,
      commit_committer_check: ccc_enabled,
      commit_committer_name_check: ccnc_enabled,
      reject_unsigned_commits: ruc_enabled,
      reject_non_dco_commits: rnd_enabled
    )
  end

  before_all do
    project.add_maintainer(maintainer)
    project.add_developer(developer)
  end

  shared_examples 'requires a license' do
    let(:push_rules_enabled) { false }

    it do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'does not include key in the response' do
    it 'succeeds' do
      get_push_rule

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'does not include key in the response' do
      get_push_rule

      expect(json_response).not_to have_key(key.to_s)
    end
  end

  shared_examples 'authorizes change param' do
    context 'when request is sent with the unauthorized parameter' do
      it 'returns forbidden' do
        subject

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when request is sent without the unauthorized parameter' do
      before do
        params.delete(unauthorized_param)
      end

      it 'returns success' do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end
    end
  end

  describe 'GET /projects/:id/push_rule' do
    subject(:get_push_rule) { get api("/projects/#{project.id}/push_rule", user) }

    before do
      create(:push_rule, project: project, **attributes)
    end

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      it 'returns project push rule' do
        get_push_rule

        expect(json_response).to eq(
          {
            "author_email_regex" => attributes[:author_email_regex],
            "branch_name_regex" => nil,
            "commit_committer_check" => true,
            "commit_committer_name_check" => true,
            "commit_message_negative_regex" => attributes[:commit_message_negative_regex],
            "commit_message_regex" => attributes[:commit_message_regex],
            "created_at" => project.reload.push_rule.created_at.iso8601(3),
            "deny_delete_tag" => false,
            "file_name_regex" => nil,
            "id" => project.push_rule.id,
            "max_file_size" => 100,
            "member_check" => false,
            "prevent_secrets" => true,
            "project_id" => project.id,
            "reject_non_dco_commits" => true,
            "reject_unsigned_commits" => true
          }
        )
      end

      it_behaves_like 'authorizing granular token permissions', :read_push_rule do
        let(:boundary_object) { project }
        let(:user) { maintainer }
        let(:request) do
          get api("/projects/#{project.id}/push_rule", personal_access_token: pat)
        end
      end

      context 'when the commit_committer_check feature is unavailable' do
        let(:ccc_enabled) { false }
        let(:key) { :commit_committer_check }

        it_behaves_like 'does not include key in the response'
      end

      context 'when the commit_committer_name_check feature is unavailable' do
        let(:ccnc_enabled) { false }
        let(:key) { :commit_committer_name_check }

        it_behaves_like 'does not include key in the response'
      end

      context 'when the reject_unsigned_commits feature is unavailable' do
        let(:ruc_enabled) { false }
        let(:key) { :reject_unsigned_commits }

        it_behaves_like 'does not include key in the response'
      end

      context 'when the reject_non_dco_commits feature is unavailable' do
        let(:rnd_enabled) { false }
        let(:key) { :reject_non_dco_commits }

        it_behaves_like 'does not include key in the response'
      end

      context 'when project name contains a dot' do
        let_it_be(:dot_project) { create(:project, path: 'project.path') }

        before_all do
          dot_project.add_maintainer(maintainer)
          create(:push_rule, project: dot_project)
        end

        it 'returns project push rule', :aggregate_failures do
          get api("/projects/#{CGI.escape(dot_project.full_path)}/push_rule", maintainer)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_a(Hash)
          expect(json_response['project_id']).to eq(dot_project.id)
        end
      end
    end

    context 'when current user is a developer' do
      let(:user) { developer }

      it 'returns 403 error' do
        get_push_rule

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /projects/:id/push_rule' do
    subject(:create_push_rule) { post api("/projects/#{project.id}/push_rule", user), params: params }

    let(:params) { attributes }

    let(:expected_response) do
      params.transform_keys(&:to_s)
    end

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      context 'when commit_committer_check feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ccc_enabled) { false }
          let(:unauthorized_param) { :commit_committer_check }
        end
      end

      context 'when commit_committer_name_check feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ccnc_enabled) { false }
          let(:unauthorized_param) { :commit_committer_name_check }
        end
      end

      context 'when reject_unsigned_commits feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ruc_enabled) { false }
          let(:unauthorized_param) { :reject_unsigned_commits }
        end
      end

      context 'when reject_non_dco_commits feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:rnd_enabled) { false }
          let(:unauthorized_param) { :reject_non_dco_commits }
        end
      end

      it 'creates the push rule', :aggregate_failures do
        create_push_rule

        expect(response).to have_gitlab_http_status(:created)

        expect(json_response['project_id']).to eq(project.id)
        expect(json_response).to include(expected_response)
      end

      it_behaves_like 'authorizing granular token permissions', :create_push_rule do
        let(:boundary_object) { project }
        let(:user) { maintainer }
        let(:request) do
          post api("/projects/#{project.id}/push_rule", personal_access_token: pat), params: attributes
        end
      end

      context 'when invalid params are provided', :aggregate_failures do
        let(:params) { { max_file_size: -10 } }

        it 'returns 400 error' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to match('max_file_size' => ['must be greater than or equal to 0'])
        end
      end

      context 'when no params are provided' do
        let(:params) { {} }

        it 'returns 400 error' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when commit_message_regex is too long', :aggregate_failures do
        let(:params) { { commit_message_regex: 'a' * 512 } }

        it 'returns 400 error' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to match('commit_message_regex' => ['is too long (maximum is 511 characters)'])
        end
      end

      context 'when commit_message_negative_regex is too long', :aggregate_failures do
        let(:params) { { commit_message_negative_regex: 'a' * 2048 } }

        it 'returns 400 error' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to match('commit_message_negative_regex' => ['is too long (maximum is 2047 characters)'])
        end
      end

      context 'when no max_file_size param is provided' do
        let(:params) { { commit_message_regex: 'JIRA\-\d+' } }

        it 'returns push rule with max_file_size set to 0', :aggregate_failures do
          create_push_rule

          expect(response).to have_gitlab_http_status(:created)

          expect(json_response['project_id']).to eq(project.id)
          expect(json_response['commit_message_regex']).to eq('JIRA\-\d+')
          expect(json_response['max_file_size']).to eq(0)
        end
      end

      context 'when a push rule already exists' do
        before do
          create(:push_rule, project: project)
        end

        it 'returns an error response' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when the current user is a developer' do
      let(:user) { developer }

      it 'returns 403 error' do
        create_push_rule

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /projects/:id/push_rule' do
    subject(:update_push_rule) { put api("/projects/#{project.id}/push_rule", user), params: params }

    let(:params) do
      {
        deny_delete_tag: false,
        commit_message_regex: 'Fixes \d+\..*',
        commit_committer_check: true,
        commit_committer_name_check: true,
        reject_unsigned_commits: true,
        reject_non_dco_commits: true
      }
    end

    context 'when a push rule exists' do
      let_it_be(:push_rule) { create(:push_rule, project: project) }

      context 'when the current user is a maintainer' do
        let(:user) { maintainer }

        it_behaves_like 'requires a license'

        context 'updates attributes as expected' do
          it 'returns success' do
            update_push_rule

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'includes the expected settings' do
            update_push_rule

            subset = params.transform_keys(&:to_s)
            expect(json_response).to include(subset)
          end
        end

        it_behaves_like 'authorizing granular token permissions', :update_push_rule do
          let(:boundary_object) { project }
          let(:user) { maintainer }
          let(:request) do
            put api("/projects/#{project.id}/push_rule", personal_access_token: pat), params: params
          end
        end

        context 'when commit_committer_check feature is unavailable' do
          it_behaves_like 'authorizes change param' do
            let(:ccc_enabled) { false }
            let(:unauthorized_param) { :commit_committer_check }
          end
        end

        context 'when commit_committer_name_check feature is unavailable' do
          it_behaves_like 'authorizes change param' do
            let(:ccnc_enabled) { false }
            let(:unauthorized_param) { :commit_committer_name_check }
          end
        end

        context 'when reject_unsigned_commits feature is unavailable' do
          it_behaves_like 'authorizes change param' do
            let(:ruc_enabled) { false }
            let(:unauthorized_param) { :reject_unsigned_commits }
          end
        end

        context 'when reject_non_dco_commits feature is unavailable' do
          it_behaves_like 'authorizes change param' do
            let(:rnd_enabled) { false }
            let(:unauthorized_param) { :reject_non_dco_commits }
          end
        end

        context 'when no parameters are provided' do
          let(:params) { {} }

          it 'returns 400 error' do
            update_push_rule

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when invalid params are provided', :aggregate_failures do
          let(:params) { { max_file_size: -10 } }

          it 'returns 400 error' do
            update_push_rule

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to match('max_file_size' => ['must be greater than or equal to 0'])
          end
        end
      end

      context 'when the current user is a developer' do
        let(:user) { developer }

        it 'returns 403 error' do
          update_push_rule

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when a push rule does not exist' do
      let(:user) { maintainer }

      it 'returns an error response', :aggregate_failures do
        expect { update_push_rule }.not_to change { PushRule.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /projects/:id/push_rule' do
    subject(:delete_push_rule) { delete api("/projects/#{project.id}/push_rule", user) }

    context 'when the push rule exists' do
      let_it_be(:push_rule) { create(:push_rule, project: project) }

      context 'when the current user is a maintainer' do
        let(:user) { maintainer }

        it_behaves_like 'requires a license'

        it 'deletes push rule from project' do
          delete_push_rule

          expect(response).to have_gitlab_http_status(:no_content)
        end

        it_behaves_like 'authorizing granular token permissions', :delete_push_rule do
          let(:boundary_object) { project }
          let(:user) { maintainer }
          let(:request) do
            delete api("/projects/#{project.id}/push_rule", personal_access_token: pat)
          end
        end
      end

      context 'when the current user is a developer' do
        let(:user) { developer }

        it 'returns a 403 error' do
          delete_push_rule

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when the push rule does not exist' do
      context 'when the current user is a maintainer' do
        let(:user) { maintainer }

        it 'returns 404' do
          delete_push_rule

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to be_an Hash
          expect(json_response['message']).to eq('404 Push rule Not Found')
        end
      end

      context 'when the current user is a developer' do
        let(:user) { developer }

        it 'returns a 403 error' do
          delete_push_rule

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
