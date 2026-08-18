# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::StatusChecks, feature_category: :security_policy_management do
  include AccessMatchersForRequest
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:another_project) { create(:project, :repository, :public) }

  let_it_be(:external_status_check) do
    create(
      :external_status_check,
      project: project,
      external_url: 'https://mock.api.test/status?token=123456789',
      name: 'first rule'
    )
  end

  let_it_be(:external_status_check_2) { create(:external_status_check, project: project, name: 'second rule') }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project, author: user) }

  let(:single_object_url) { "/projects/#{project.id}/external_status_checks/#{external_status_check.id}" }
  let(:collection_url) { "/projects/#{project.id}/external_status_checks" }
  let(:sha) { merge_request.diff_head_sha }
  let(:status) { '' }

  subject { get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_checks", user), params: { external_status_check_id: external_status_check.id, sha: sha } }

  describe 'GET :id/merge_requests/:merge_request_iid/status_checks' do
    before do
      stub_licensed_features(external_status_checks: true)
    end

    context 'external url response' do
      context 'when access level is at least `reporter`' do
        before do
          project.add_member(user, :reporter)
        end

        it 'is empty' do
          subject

          expect(json_response[0]["external_url"]).to eq('')
          expect(json_response[1]["external_url"]).to eq('')
        end
      end

      context 'when access level is at least `developer`' do
        before do
          project.add_member(user, :developer)
        end

        it 'has excluded the sensitive token url param' do
          subject

          expect(json_response[0]["external_url"]).to eq('https://mock.api.test/status')
          expect(json_response[1]["external_url"]).to eq(external_status_check_2.external_url)
        end
      end
    end

    context 'when current_user has access' do
      before do
        project.add_member(user, :maintainer)
      end

      context 'when merge request has received status check responses' do
        let!(:non_applicable_check) { create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: 'different-branch', project: project)]) }
        let!(:branch_specific_check) { create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: merge_request.target_branch, project: project)]) }
        let!(:status_check_response) { create(:status_check_response, external_status_check: external_status_check, merge_request: merge_request, sha: sha) }

        it 'returns a 200' do
          subject

          expect(response).to have_gitlab_http_status(:success)
        end

        it 'returns the total number of status checks for the MRs project' do
          subject

          expect(json_response.size).to eq(3)
        end

        it 'has the correct status values' do
          subject

          expect(json_response[0]["status"]).to eq('passed')
          expect(json_response[1]["status"]).to eq('pending')
          expect(json_response[2]["status"]).to eq('pending')
        end

        it_behaves_like 'authorizing granular token permissions', :read_external_status_check do
          let(:boundary_object) { project }
          let(:request) do
            get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_checks", personal_access_token: pat), params: { external_status_check_id: external_status_check.id, sha: sha }
          end
        end
      end
    end
  end

  describe 'POST :id/:merge_requests/:merge_request_iid/status_check_responses' do
    subject { post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_check_responses", user), params: { external_status_check_id: external_status_check.id, sha: sha, status: status } }

    let(:status) { 'passed' }

    shared_examples 'not creating a status check response and returns error' do |status, error = {}|
      it 'does not create status check response and returns error' do
        expect { subject }.not_to change { MergeRequests::StatusCheckResponse.count }

        expect(response).to have_gitlab_http_status(status)
        expect(json_response).to include(error.as_json) if error.present?
      end
    end

    context 'permissions' do
      using RSpec::Parameterized::TableSyntax

      where(:user_permissions, :applies_to_target_project, :expected_status) do
        :maintainer | true  | :created
        :maintainer | false | :not_found
        :developer  | true  | :created
        :developer  | false | :not_found
        :guest      | true  | :forbidden
        :guest      | false | :not_found
      end

      with_them do
        before do
          stub_licensed_features(external_status_checks: true)

          if applies_to_target_project
            project.add_member(user, user_permissions)
          else
            another_project.add_member(user, user_permissions)
          end
        end

        it 'returns the correct status' do
          subject

          expect(response).to have_gitlab_http_status(expected_status)
        end
      end
    end

    # Security: regression guard for the external_url query-string disclosure.
    context 'external_url in the response body' do
      before do
        stub_licensed_features(external_status_checks: true)
        project.add_member(user, :developer)
      end

      it 'excludes the sensitive query string from the external status check URL', :aggregate_failures do
        subject

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response.dig('external_status_check', 'external_url')).to eq('https://mock.api.test/status')
      end
    end

    context 'when user has access' do
      before do
        stub_licensed_features(external_status_checks: true)
        project.add_member(user, :maintainer) if user
      end

      context 'when the request is valid' do
        it 'creates a status check response and returns the correct status' do
          expect { subject }.to change { MergeRequests::StatusCheckResponse.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when external status check ID does not belong to the requested project' do
        let_it_be(:external_status_check) { create(:external_status_check) }

        it_behaves_like 'not creating a status check response and returns error', :not_found, message: "404 Not found"
      end

      context 'when sha is not the source branch HEAD' do
        let(:sha) { 'notarealsha' }

        it_behaves_like 'not creating a status check response and returns error', :conflict
      end

      context 'when user is not authenticated' do
        let(:user) { nil }

        it_behaves_like 'not creating a status check response and returns error', :unauthorized, message: '401 Unauthorized'
      end

      context 'when service returns validation errors' do
        context 'when sha is missing' do
          subject do
            post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_check_responses", user),
              params: { external_status_check_id: external_status_check.id, status: status }
          end

          it_behaves_like 'not creating a status check response and returns error', :bad_request, error: 'sha is missing'
        end

        context 'when status is invalid' do
          let(:status) { 'invalid_status' }

          it_behaves_like 'not creating a status check response and returns error', :bad_request, error: 'status does not have a valid value'
        end

        context 'when status is missing' do
          subject do
            post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_check_responses", user),
              params: { external_status_check_id: external_status_check.id, sha: sha }
          end

          it_behaves_like 'not creating a status check response and returns error', :bad_request, error: 'status is missing, status does not have a valid value'
        end

        context 'when service returns other validation errors' do
          before do
            allow_next_instance_of(::MergeRequests::StatusCheckResponses::CreateService) do |service|
              allow(service).to receive(:execute).with(merge_request).and_return(
                ServiceResponse.error(
                  message: 'Validation failed',
                  reason: :bad_request,
                  payload: { errors: "Sha can't be blank" }
                )
              )
            end
          end

          it_behaves_like 'not creating a status check response and returns error', :bad_request, message: 'Sha can\'t be blank'
        end
      end

      context 'when service returns permission errors' do
        before do
          project.project_members.where(user: user).delete_all
          project.add_member(user, :guest)
        end

        it_behaves_like 'not creating a status check response and returns error', :forbidden, message: '403 Forbidden'
      end

      it_behaves_like 'authorizing granular token permissions', :update_external_status_check do
        let(:boundary_object) { project }
        let(:request) do
          post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_check_responses", personal_access_token: pat), params: { external_status_check_id: external_status_check.id, sha: sha, status: status }
        end
      end
    end
  end

  describe 'DELETE projects/:id/external_status_checks/:check_id' do
    before do
      stub_licensed_features(external_status_checks: true)
    end

    it 'deletes the specified external status check' do
      expect do
        delete api(single_object_url, project.first_owner)
      end.to change { MergeRequests::ExternalStatusCheck.count }.by(-1)
    end

    context 'when feature is disabled, unlicensed or user has permission' do
      where(:licensed, :project_owner, :status) do
        false | false | :not_found
        false | true  | :unauthorized
        true  | false | :not_found
        true  | true  | :success
      end

      with_them do
        before do
          stub_licensed_features(external_status_checks: licensed)
        end

        it 'returns the correct status code' do
          delete api(single_object_url, (project_owner ? project.first_owner : build(:user)))

          expect(response).to have_gitlab_http_status(status)
        end
      end
    end

    it_behaves_like 'authorizing granular token permissions', :delete_external_status_check_service do
      let(:boundary_object) { project }
      let(:user) { project.first_owner }
      let(:request) do
        delete api(single_object_url, personal_access_token: pat)
      end
    end
  end

  describe 'POST projects/:id/external_status_checks' do
    context 'successfully creates an external status check' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      subject do
        post api("/projects/#{project.id}/external_status_checks", project.first_owner), params: attributes_for(:external_status_check)
      end

      it 'creates a new external status check' do
        expect { subject }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)
      end

      context 'with protected branches' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

        let(:params) do
          { name: 'New rule', external_url: 'https://gitlab.com/test/example.json', protected_branch_ids: protected_branch.id, shared_secret: 'shared_secret' }
        end

        subject do
          post api("/projects/#{project.id}/external_status_checks", project.first_owner), params: params
        end

        it 'returns expected status code' do
          subject

          expect(response).to have_gitlab_http_status(:created)
        end

        it 'creates protected branch records' do
          subject

          expect(MergeRequests::ExternalStatusCheck.last.protected_branches.count).to eq 1
        end

        it 'responds with expected JSON' do
          subject

          expect(json_response['id']).not_to be_nil
          expect(json_response['name']).to eq('New rule')
          expect(json_response['hmac']).to be(true)
          expect(json_response['external_url']).to eq('https://gitlab.com/test/example.json')
          expect(json_response['protected_branches'].size).to eq(1)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_external_status_check_service do
        let(:boundary_object) { project }
        let(:user) { project.first_owner }
        let(:request) do
          post api("/projects/#{project.id}/external_status_checks", personal_access_token: pat), params: attributes_for(:external_status_check)
        end
      end
    end

    context 'when feature is disabled, unlicensed or user has permission' do
      where(:licensed, :project_owner, :status) do
        false | false | :not_found
        false | true  | :unauthorized
        true  | false | :not_found
        true  | true  | :created
      end

      with_them do
        before do
          stub_licensed_features(external_status_checks: licensed)
        end

        it 'returns the correct status code' do
          post api("/projects/#{project.id}/external_status_checks", (project_owner ? project.owner : build(:user))), params: attributes_for(:external_status_check)

          expect(response).to have_gitlab_http_status(status)
        end
      end
    end
  end

  describe 'GET projects/:id/external_status_checks' do
    let_it_be(:protected_branches) { create_list(:protected_branch, 3, project: project) }

    before_all do
      create(:external_status_check) # Creating an orphaned external_status_check to make sure project scoping works as expected
    end

    before do
      stub_licensed_features(external_status_checks: true)
    end

    it_behaves_like 'authorizing granular token permissions', :read_external_status_check_service do
      let(:boundary_object) { project }
      let(:user) { project.first_owner }
      let(:request) do
        get api(collection_url, personal_access_token: pat)
      end
    end

    it 'responds with expected JSON', :aggregate_failures do
      get api(collection_url, project.first_owner)

      expect(json_response.size).to eq(2)
      expect(json_response.map { |r| r['name'] }).to contain_exactly('first rule', 'second rule')
    end

    it 'paginates correctly' do
      get api(collection_url, project.first_owner), params: { per_page: 1 }

      expect_paginated_array_response([external_status_check.id])
    end

    context 'when feature is disabled, unlicensed or user has permission' do
      where(:licensed, :project_owner, :status) do
        false | false | :not_found
        false | true  | :unauthorized
        true  | false | :not_found
        true  | true  | :success
      end

      with_them do
        before do
          stub_licensed_features(external_status_checks: licensed)
        end

        it 'returns the correct status code' do
          get api(collection_url, (project_owner ? project.first_owner : build(:user)))

          expect(response).to have_gitlab_http_status(status)
        end
      end
    end

    context 'when user lacks read_external_status_check permission' do
      let_it_be(:reporter) { create(:user) }

      before_all do
        project.add_reporter(reporter)
      end

      it 'returns unauthorized' do
        get api(collection_url, reporter)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe 'POST projects/:id/merge_requests/:merge_request_iid/status_checks/:external_status_check_id/retry' do
    subject(:retry_failed_status_check) do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_checks/#{external_status_check.id}/retry", user)
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(external_status_checks: false)
        project.add_member(user, :maintainer)
      end

      it 'returns unauthorized status' do
        retry_failed_status_check

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when licensed' do
      using RSpec::Parameterized::TableSyntax

      before do
        stub_licensed_features(external_status_checks: true)
      end

      context 'permissions' do
        where(:user_permissions, :applies_to_target_project, :expected_status) do
          :maintainer | true  | :accepted
          :maintainer | false | :not_found
          :developer  | true  | :accepted
          :developer  | false | :not_found
          :guest      | true  | :forbidden
          :guest      | false | :not_found
        end

        with_them do
          before do
            if applies_to_target_project
              project.add_member(user, user_permissions)
            else
              another_project.add_member(user, user_permissions)
            end

            create(
              :status_check_response,
              merge_request: merge_request,
              external_status_check: external_status_check,
              sha: merge_request.diff_head_sha,
              status: 'failed'
            )
          end

          it 'returns the correct status' do
            retry_failed_status_check

            expect(response).to have_gitlab_http_status(expected_status)
          end
        end
      end

      context 'when current_user has access' do
        before do
          stub_licensed_features(external_status_checks: true)
          project.add_member(user, :maintainer)
        end

        context 'when status check is failed' do
          let_it_be(:data) { merge_request.to_hook_data(user) }

          before do
            create(
              :status_check_response,
              merge_request: merge_request,
              external_status_check: external_status_check,
              sha: merge_request.diff_head_sha,
              status: 'failed'
            )
          end

          it_behaves_like 'authorizing granular token permissions', :retry_external_status_check do
            let(:boundary_object) { project }
            let(:request) do
              post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/status_checks/#{external_status_check.id}/retry", personal_access_token: pat)
            end
          end

          it 'calls async execute with correct data' do
            expect_next_found_instance_of(::MergeRequests::ExternalStatusCheck) do |instance|
              instance.to receive(:async_execute).with(data)
            end

            retry_failed_status_check
          end

          it 'returns accepted response' do
            retry_failed_status_check

            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'updates last status check response' do
            retry_failed_status_check

            expect(merge_request.status_check_responses.last.status).to eq('pending')
            expect(merge_request.status_check_responses.last.retried_at).not_to be_nil
          end
        end

        context 'when status check is passed' do
          before do
            create(
              :status_check_response,
              merge_request: merge_request,
              external_status_check: external_status_check,
              sha: merge_request.diff_head_sha,
              status: 'passed'
            )
          end

          it 'returns unprocessable_entity response', :aggregate_failures do
            retry_failed_status_check

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(response.body).to eq('{"message":"External status check must be failed"}')
          end
        end
      end
    end
  end

  describe 'PUT projects/:id/external_status_checks/:check_id' do
    let(:params) { { external_url: 'http://newvalue.com', name: 'new name' } }

    context 'successfully updates an external status check' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      subject do
        put api(single_object_url, project.first_owner), params: params
      end

      it 'updates an external status check' do
        expect { subject }.to change { external_status_check.reload.external_url }.to eq('http://newvalue.com')
      end

      it 'responds with correct http status' do
        subject

        expect(response).to have_gitlab_http_status(:success)
      end

      it_behaves_like 'authorizing granular token permissions', :update_external_status_check_service do
        let(:boundary_object) { project }
        let(:user) { project.first_owner }
        let(:request) do
          put api(single_object_url, personal_access_token: pat), params: params
        end
      end

      context 'when referencing a protected branch outside of the project' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch) }

        let(:params) do
          { name: 'New rule', external_url: 'https://gitlab.com/test/example.json', protected_branch_ids: protected_branch.id }
        end

        subject do
          put api(single_object_url, project.first_owner), params: params
        end

        it 'is invalid' do
          subject

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'with protected branches' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

        let(:params) do
          { name: 'New rule', external_url: 'https://gitlab.com/test/example.json', protected_branch_ids: protected_branch.id, shared_secret: 'shared_secret' }
        end

        subject do
          put api(single_object_url, project.first_owner), params: params
        end

        it 'returns expected status code' do
          subject

          expect(response).to have_gitlab_http_status(:success)
        end

        it 'creates protected branch records' do
          expect { subject }.to change { MergeRequests::ExternalStatusCheck.last.protected_branches }
        end

        it 'responds with expected JSON', :aggregate_failures do
          subject

          expect(json_response['id']).not_to be_nil
          expect(json_response['name']).to eq('New rule')
          expect(json_response['hmac']).to be(true)
          expect(json_response['external_url']).to eq('https://gitlab.com/test/example.json')
          expect(json_response['protected_branches'].size).to eq(1)
        end
      end
    end

    context 'when feature is disabled, unlicensed or user has permission' do
      where(:licensed, :project_owner, :status) do
        false | false | :not_found
        false | true  | :unauthorized
        true  | false | :not_found
        true  | true  | :success
      end

      with_them do
        before do
          stub_licensed_features(external_status_checks: licensed)
        end

        it 'returns the correct status code' do
          put api(single_object_url, (project_owner ? project.first_owner : build(:user))), params: attributes_for(:external_status_check)

          expect(response).to have_gitlab_http_status(status)
        end
      end
    end
  end
end
