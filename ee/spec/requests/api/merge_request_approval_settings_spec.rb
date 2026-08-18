# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::MergeRequestApprovalSettings, feature_category: :source_code_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:setting) { create(:group_merge_request_approval_setting, group: group) }

  shared_examples "resolvable" do
    using RSpec::Parameterized::TableSyntax

    where(:instance_prevents_approval, :group_allows_approval, :value, :locked, :inherited_from) do
      true  | true  | false | true  | 'instance'
      true  | false | false | true  | 'instance'
      false | true  | true  | false | nil
      false | false | false | false | nil
    end

    with_them do
      before do
        stub_ee_application_setting(instance_flag => instance_prevents_approval)
        group.group_merge_request_approval_setting.update!(group_flag => group_allows_approval)

        get api(url, user)
      end

      let(:object) { json_response[group_flag.to_s] }

      it 'has the correct value' do
        expect(object['value']).to eq(value)
      end

      it 'has the correct locked status' do
        expect(object['locked']).to eq(locked)
      end

      it 'has the correct inheritance' do
        expect(object['inherited_from']).to eq(inherited_from)
      end
    end
  end

  describe 'GET /groups/:id/merge_request_approval_settings' do
    let(:url) { "/groups/#{group.id}/merge_request_approval_setting" }

    context 'when the user is authorised' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
          .with(user, :admin_merge_request_approval_settings, group)
          .and_return(true)
      end

      context 'allow_author_approval values' do
        let(:instance_flag) { :prevent_merge_requests_author_approval }
        let(:group_flag) { :allow_author_approval }

        it_behaves_like 'resolvable'
      end

      context 'allow_committer_approval values' do
        let(:instance_flag) { :prevent_merge_requests_committers_approval }
        let(:group_flag) { :allow_committer_approval }

        it_behaves_like 'resolvable'
      end

      context 'allow_overrides_to_approver_list_per_merge_request values' do
        let(:instance_flag) { :disable_overriding_approvers_per_merge_request }
        let(:group_flag) { :allow_overrides_to_approver_list_per_merge_request }

        it_behaves_like 'resolvable'
      end

      it 'matches the response schema' do
        get api(url, user)

        expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
      end

      context "granular token permissions" do
        before do
          group.add_owner(user)
        end

        it_behaves_like "authorizing granular token permissions", :read_merge_request_approval_setting do
          let(:boundary_object) { group }
          let(:request) do
            get api(url, personal_access_token: pat)
          end
        end
      end

      context 'when the group does not have existing settings' do
        before do
          group.group_merge_request_approval_setting.delete
        end

        it 'returns in-memory default settings', :aggregate_failures do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['allow_author_approval']['value']).to be(true)
          expect(json_response['allow_committer_approval']['value']).to be(true)
          expect(json_response['allow_overrides_to_approver_list_per_merge_request']['value']).to be(true)
          expect(json_response['retain_approvals_on_push']['value']).to be(true)
          expect(json_response['selective_code_owner_removals']['value']).to be(false)
          expect(json_response['require_password_to_approve']['value']).to be(false)
          expect(json_response['require_reauthentication_to_approve']['value']).to be(false)
        end
      end

      context 'when the user is not authorised' do
        before do
          allow(Ability).to receive(:allowed?)
            .with(user, :admin_merge_request_approval_settings, group)
            .and_return(false)
        end

        it 'returns 403 status' do
          get api(url, user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'PUT /groups/:id/merge_request_approval_setting' do
    let(:url) { "/groups/#{group.id}/merge_request_approval_setting" }
    let(:params) { { require_reauthentication_to_approve: true, allow_author_approval: true } }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
    end

    context 'when the user is authorised' do
      before do
        allow(Ability).to receive(:allowed?)
          .with(user, :admin_merge_request_approval_settings, group)
          .and_return(true)
      end

      it 'returns 200 status with correct response body', :aggregate_failures do
        put api(url, user), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['allow_author_approval']['value']).to be(true)
        expect(json_response['require_reauthentication_to_approve']['value']).to be(true)
      end

      it 'matches the response schema' do
        put api(url, user), params: params

        expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
      end

      context "granular token permissions" do
        before do
          group.add_owner(user)
        end

        it_behaves_like "authorizing granular token permissions", :update_merge_request_approval_setting do
          let(:boundary_object) { group }
          let(:request) do
            put api(url, personal_access_token: pat), params: params
          end
        end
      end

      context 'when password and reauthentication are set' do
        using RSpec::Parameterized::TableSyntax
        where(:reauth, :password, :outcome) do
          false | false | false
          false | nil   | false
          false | true  | false
          nil   | false | false
          nil   | true  | true
          true  | false | true
          true  | nil   | true
          true  | true  | true
        end

        with_them do
          let(:params) { {} }

          it "sets with precedence for require_reauthentication_to_approve and mirors" do
            params[:require_password_to_approve] = password unless password.nil?
            params[:require_reauthentication_to_approve] = reauth unless reauth.nil?

            put api(url, user), params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['require_password_to_approve']['value']).to eq(outcome)
            expect(json_response['require_reauthentication_to_approve']['value']).to eq(outcome)
          end
        end
      end

      context 'when update fails' do
        let(:params) { { allow_author_approval: 45 } }

        it 'returns 400 status', :aggregate_failures do
          put api(url, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to match(/allow_.*_approval is invalid/)
        end
      end

      context 'when invalid params' do
        let(:params) { {} }

        it 'returns 400 status with error message', :aggregate_failures do
          put api(url, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to match(/at least one parameter must be provided/)
        end
      end
    end

    context 'when the user is not authorised' do
      before do
        allow(Ability).to receive(:allowed?)
          .with(user, :admin_merge_request_approval_settings, group)
          .and_return(false)
      end

      it 'returns 403 status' do
        put api(url, user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /projects/:id/merge_request_approval_settings' do
    let(:url) { "/projects/#{project.id}/merge_request_approval_setting" }

    before do
      group.add_owner(user)
      allow(Ability).to receive(:allowed?).and_call_original
      stub_licensed_features(merge_request_approvers: true)
      allow(Ability).to receive(:allowed?)
                          .with(user, :admin_merge_request_approval_settings, project)
                          .and_return(true)
    end

    it 'matches the response schema' do
      get api(url, user)

      expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
    end

    it_behaves_like "authorizing granular token permissions", :read_merge_request_approval_setting do
      let(:boundary_object) { project }
      let(:request) do
        get api(url, personal_access_token: pat)
      end
    end

    context 'when the project does not have existing settings' do
      before do
        project.update!(
          merge_requests_author_approval: nil,
          merge_requests_disable_committers_approval: nil,
          disable_overriding_approvers_per_merge_request: nil,
          reset_approvals_on_push: nil,
          require_password_to_approve: nil,
          require_reauthentication_to_approve: nil
        )
      end

      it 'returns in-memory default settings', :aggregate_failures do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['allow_author_approval']['value']).to be(false)
        expect(json_response['allow_committer_approval']['value']).to be(false)
        expect(json_response['allow_overrides_to_approver_list_per_merge_request']['value']).to be(false)
        expect(json_response['retain_approvals_on_push']['value']).to be(false)
        expect(json_response['selective_code_owner_removals']['value']).to be(false)
        expect(json_response['require_password_to_approve']['value']).to be(false)
        expect(json_response['require_reauthentication_to_approve']['value']).to be(false)
      end
    end

    context 'when a security policy enforces prevent_editing_approval_rules' do
      before do
        allow_next_found_instance_of(Project) do |found_project|
          allow(found_project).to receive(:policy_prevents_editing_approval_rules?).and_return(true)
        end
      end

      it 'serializes enforced_by_policy on allow_overrides_to_approver_list_per_merge_request', :aggregate_failures do
        get api(url, user)

        expect(response).to have_gitlab_http_status(:ok)
        overrides = json_response['allow_overrides_to_approver_list_per_merge_request']
        expect(overrides['enforced_by_policy']).to be true
        expect(overrides['locked']).to be true
        expect(overrides['value']).to be false
      end
    end
  end

  describe 'PUT /projects/:id/merge_request_approval_settings' do
    let(:url) { "/projects/#{project.id}/merge_request_approval_setting" }
    let(:params) { { retain_approvals_on_push: false } }

    before do
      group.add_owner(user)
      allow(Ability).to receive(:allowed?).and_call_original
      stub_licensed_features(merge_request_approvers: true)
      allow(Ability).to receive(:allowed?)
                          .with(user, :admin_merge_request_approval_settings, project)
                          .and_return(true)
      group.group_merge_request_approval_setting.delete
    end

    it 'matches the response schema and updates the params' do
      put api(url, user), params: params

      expect(project.reset_approvals_on_push).to be true

      expect(response).to match_response_schema('public_api/v4/group_merge_request_approval_settings', dir: 'ee')
    end

    describe 'preserving unspecified settings' do
      before do
        project.update!(
          merge_requests_author_approval: false,
          merge_requests_disable_committers_approval: false,
          disable_overriding_approvers_per_merge_request: false,
          reset_approvals_on_push: false,
          require_password_to_approve: true
        )
      end

      it 'does not reset unspecified boolean settings to false', :aggregate_failures do
        put api(url, user), params: { allow_author_approval: true }

        expect(response).to have_gitlab_http_status(:ok)

        project.reload

        expect(project.merge_requests_author_approval).to be true
        expect(project.merge_requests_disable_committers_approval).to be false
        expect(project.disable_overriding_approvers_per_merge_request).to be false
        expect(project.reset_approvals_on_push).to be false
        expect(project.require_password_to_approve).to be true
      end

      it 'preserves project_setting attributes when not specified', :aggregate_failures do
        project.project_setting.update!(require_reauthentication_to_approve: true)

        put api(url, user), params: { allow_author_approval: true }

        expect(response).to have_gitlab_http_status(:ok)

        project.project_setting.reload
        expect(project.project_setting.require_reauthentication_to_approve).to be true
      end
    end

    it_behaves_like "authorizing granular token permissions", :update_merge_request_approval_setting do
      let(:boundary_object) { project }
      let(:request) do
        put api(url, personal_access_token: pat), params: params
      end
    end

    context 'when enabling selective_code_owner_removals and retain_approvals_on_push' do
      let(:params) { { retain_approvals_on_push: true, selective_code_owner_removals: true } }

      it 'updates the params' do
        put api(url, user), params: params

        expect(response).to have_gitlab_http_status(:ok)

        project.reload
        expect(project.reset_approvals_on_push).to be false
        expect(project.project_setting.selective_code_owner_removals).to be true
      end
    end

    context 'when enabling selective_code_owner_removals with retain_approvals_on_push disabled' do
      let(:params) { { selective_code_owner_removals: true } }

      it 'returns error response and does not update the params' do
        put api(url, user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)

        project.reload
        expect(project.project_setting.selective_code_owner_removals).to be false
      end
    end
  end
end
