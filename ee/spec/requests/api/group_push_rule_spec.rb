# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupPushRule, 'GroupPushRule', :aggregate_failures, :api, feature_category: :source_code_management do
  include ApiHelpers

  let_it_be_with_reload(:group) { create(:group) }

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let(:attributes) do
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
    group.add_maintainer(maintainer)
    group.add_developer(developer)
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

  shared_examples 'retrieves a group push rule' do
    subject(:get_push_rule) { get api("/groups/#{group.id}/push_rule", user) }

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      it 'returns group push rule' do
        get_push_rule

        expect(json_response).to eq({
          "author_email_regex" => attributes[:author_email_regex],
          "branch_name_regex" => nil,
          "commit_committer_check" => true,
          "commit_committer_name_check" => true,
          "commit_message_negative_regex" => attributes[:commit_message_negative_regex],
          "commit_message_regex" => attributes[:commit_message_regex],
          "created_at" => push_rule.created_at.iso8601(3),
          "deny_delete_tag" => false,
          "file_name_regex" => nil,
          "id" => push_rule.id,
          "max_file_size" => 100,
          "member_check" => false,
          "reject_non_dco_commits" => true,
          "prevent_secrets" => true,
          "reject_unsigned_commits" => true
        })
      end

      it 'matches response schema' do
        get_push_rule

        expect(response).to match_response_schema('entities/group_push_rules')
      end

      it_behaves_like 'authorizing granular token permissions', :read_push_rule do
        let(:boundary_object) { group }
        let(:user) { maintainer }
        let(:request) do
          get api("/groups/#{group.id}/push_rule", personal_access_token: pat)
        end
      end

      context 'when group name contains a dot' do
        before do
          group.update!(path: 'group.path')
        end

        it 'returns group push rule', :aggregate_failures do
          get api("/groups/#{CGI.escape(group.reload.full_path)}/push_rule", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_an Hash
          expect(json_response['id']).to eq(push_rule.id)
        end
      end

      context 'when reject_unsigned_commits feature is unavailable' do
        let(:ruc_enabled) { false }
        let(:key) { :reject_unsigned_commits }

        it_behaves_like 'does not include key in the response'
      end

      context 'when commit_committer_check is unavailable' do
        let(:ccc_enabled) { false }
        let(:key) { :commit_committer_check }

        it_behaves_like 'does not include key in the response'
      end

      context 'when commit_committer_name_check is unavailable' do
        let(:ccnc_enabled) { false }
        let(:key) { :commit_committer_name_check }

        it_behaves_like 'does not include key in the response'
      end

      context 'when reject_non_dco_commits is unavailable' do
        let(:rnd_enabled) { false }
        let(:key) { :reject_non_dco_commits }

        it_behaves_like 'does not include key in the response'
      end

      context 'when push rule does not exist' do
        let_it_be(:no_push_rule_group) { create(:group) }

        it 'returns 400 error' do
          get api("/groups/#{no_push_rule_group.id}/push_rule", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when current user is a developer' do
      let(:user) { developer }

      it 'returns 404 error' do
        get_push_rule

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'creates a group push rule' do
    let(:params) { attributes }

    subject(:create_push_rule) { post api("/groups/#{group.id}/push_rule", user), params: params }

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      it 'returns success', :aggregate_failures do
        create_push_rule

        expect(response).to have_gitlab_http_status(:created)
      end

      it do
        expect { create_push_rule }.to change { GroupPushRule.count }.by(1)
      end

      it 'creates the push rule' do
        create_push_rule

        group.reload

        expect(push_rule.author_email_regex).to eq(attributes[:author_email_regex])
        expect(push_rule.commit_committer_check).to eq(attributes[:commit_committer_check])
        expect(push_rule.commit_committer_name_check).to eq(attributes[:commit_committer_name_check])
        expect(push_rule.commit_message_negative_regex).to eq(attributes[:commit_message_negative_regex])
        expect(push_rule.commit_message_regex).to eq(attributes[:commit_message_regex])
        expect(push_rule.deny_delete_tag).to eq(attributes[:deny_delete_tag])
        expect(push_rule.max_file_size).to eq(attributes[:max_file_size])
        expect(push_rule.member_check).to eq(attributes[:member_check])
        expect(push_rule.prevent_secrets).to eq(attributes[:prevent_secrets])
        expect(push_rule.reject_unsigned_commits).to eq(attributes[:reject_unsigned_commits])
        expect(push_rule.reject_non_dco_commits).to eq(attributes[:reject_non_dco_commits])
      end

      it_behaves_like 'authorizing granular token permissions', :create_push_rule do
        let(:boundary_object) { group }
        let(:user) { maintainer }
        let(:request) do
          post api("/groups/#{group.id}/push_rule", personal_access_token: pat), params: attributes
        end
      end

      context 'when a push rule already exists' do
        before do
          create(:group_push_rule, group: group)
        end

        it 'returns an error response' do
          create_push_rule

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Group push rule exists, try updating')
        end
      end

      context 'when no params are provided' do
        let(:params) { {} }

        it 'returns 400 error', :aggregate_failures do
          create_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('at least one parameter must be provided')
        end
      end

      context 'when reject_unsigned_commits feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ruc_enabled) { false }
          let(:unauthorized_param) { :reject_unsigned_commits }
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

      context 'when reject_non_dco_commits feature is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:rnd_enabled) { false }
          let(:unauthorized_param) { :reject_non_dco_commits }
        end
      end
    end

    context 'when the current user is a developer' do
      let(:user) { developer }

      it 'returns 404 error' do
        create_push_rule

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'updates a group push rule' do
    subject(:update_push_rule) { put api("/groups/#{group.id}/push_rule", user), params: params }

    let(:attributes_for_update) do
      {
        author_email_regex: '^[A-Za-z0-9.]+@disney.com$',
        reject_unsigned_commits: true,
        commit_committer_name_check: false,
        commit_committer_check: false,
        reject_non_dco_commits: true
      }
    end

    let(:params) { attributes_for_update }

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      it 'returns success' do
        update_push_rule

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'updates the push rule' do
        expect { update_push_rule }.to change { push_rule.reload.author_email_regex }
          .from(attributes[:author_email_regex])
          .to(attributes_for_update[:author_email_regex])
      end

      it_behaves_like 'authorizing granular token permissions', :update_push_rule do
        let(:boundary_object) { group }
        let(:user) { maintainer }
        let(:request) do
          put api("/groups/#{group.id}/push_rule", personal_access_token: pat),
            params: { author_email_regex: '^[A-Za-z0-9.]+@disney.com$' }
        end
      end

      context 'when push rule does not exist for group' do
        let(:group_without_push_rule) { create(:group) }

        before do
          group_without_push_rule.add_maintainer(maintainer)
        end

        it 'returns 404 error', :aggregate_failures do
          put api("/groups/#{group_without_push_rule.id}/push_rule", user), params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to include('Push rule Not Found')
        end
      end

      context 'when no params are provided' do
        let(:params) { {} }

        it 'returns 400 error' do
          update_push_rule

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('at least one parameter must be provided')
        end
      end

      context 'when reject_unsigned_commits is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ruc_enabled) { false }
          let(:unauthorized_param) { :reject_unsigned_commits }
        end
      end

      context 'when commit_committer_check is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ccc_enabled) { false }
          let(:unauthorized_param) { :commit_committer_check }
        end
      end

      context 'when commit_committer_name_check is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:ccnc_enabled) { false }
          let(:unauthorized_param) { :commit_committer_name_check }
        end
      end

      context 'when reject_non_dco_commits is unavailable' do
        it_behaves_like 'authorizes change param' do
          let(:rnd_enabled) { false }
          let(:unauthorized_param) { :reject_non_dco_commits }
        end
      end
    end

    context 'when the current user is a developer' do
      let(:user) { developer }

      it 'returns 404 error' do
        update_push_rule

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'deletes a group push rule' do
    subject(:delete_push_rule) { delete api("/groups/#{group.id}/push_rule", user) }

    context 'when the current user is a maintainer' do
      let(:user) { maintainer }

      it_behaves_like 'requires a license'

      context 'when the push rule exists' do
        it 'deletes push rule from group', :aggregate_failures do
          delete_push_rule

          group.reload

          expect(response).to have_gitlab_http_status(:no_content)
          expect(push_rule).to be_nil
        end

        it_behaves_like 'authorizing granular token permissions', :delete_push_rule do
          let(:boundary_object) { group }
          let(:user) { maintainer }
          let(:request) do
            delete api("/groups/#{group.id}/push_rule", personal_access_token: pat)
          end
        end
      end

      context 'when push rule does not exist' do
        let(:no_push_rule_group) { create(:group) }

        it 'returns 404 error' do
          delete api("/groups/#{no_push_rule_group.id}/push_rule", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the current user is a developer' do
      let(:user) { developer }

      it 'returns a 404 error' do
        delete_push_rule

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /groups/:id/push_rule' do
    it_behaves_like 'retrieves a group push rule' do
      before do
        create(:group_push_rule, group: group, **attributes)
      end

      let(:push_rule) { group.group_push_rule }
    end
  end

  describe 'POST /groups/:id/push_rule' do
    it_behaves_like 'creates a group push rule' do
      let(:push_rule) { group.group_push_rule }
    end
  end

  describe 'PUT /groups/:id/push_rule' do
    it_behaves_like 'updates a group push rule' do
      let!(:push_rule) { create(:group_push_rule, group: group, **attributes) }
    end
  end

  describe 'DELETE /groups/:id/push_rule' do
    it_behaves_like 'deletes a group push rule' do
      let(:push_rule) { group.group_push_rule }

      before do
        create(:group_push_rule, group: group, **attributes)
      end
    end
  end
end
