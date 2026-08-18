# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::CodeReview, :with_current_organization, feature_category: :duo_code_review do
  include HttpBasicAuthHelpers

  shared_context 'with DAP Duo Code Review enabled' do
    before do
      allow(::Gitlab::Duo::CodeReview).to receive(:dap?).and_return(true)
    end
  end

  shared_context 'with DAP Duo Code Review disabled' do
    before do
      allow(::Gitlab::Duo::CodeReview).to receive(:dap?).and_return(false)
    end
  end

  let_it_be(:foundational_flow) { Ai::Catalog::FoundationalFlow['code_review/v1'] }
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:oauth_app) { create(:doorkeeper_application) }
  let_it_be(:scopes) { ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{user.id}"] }
  let_it_be(:service_account) do
    create(:user, :service_account,
      composite_identity_enforced: true,
      organization: organization,
      provisioned_by_group: group
    )
  end

  let_it_be(:catalog_item) do
    create(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'code_review/v1')
  end

  let_it_be(:parent_item_consumer) do
    create(:ai_catalog_item_consumer, item: catalog_item, group: group, service_account: service_account)
  end

  let_it_be(:child_item_consumer) do
    create(:ai_catalog_item_consumer, item: catalog_item, project: project, parent_item_consumer: parent_item_consumer)
  end

  let_it_be(:token) do
    create(:oauth_access_token,
      organization: organization,
      application: oauth_app,
      resource_owner: service_account,
      expires_in: 1.hour,
      scopes: scopes
    )
  end

  before_all do
    group.add_developer(user)
    project.add_developer(service_account)

    # Create bot user: The code under test implicitly creates this, causing
    # the specs for POST going over the query limit of 100
    create(:user, :duo_code_review_bot)
  end

  before do
    # Clear memoization to prevent state leakage from other specs that may have
    # called catalog_item before ai_catalog_items records were created
    foundational_flow.clear_memoization(:catalog_item)
  end

  describe 'POST /ai/duo_workflows/code_review/add_comments' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }

    let(:path) { "/ai/duo_workflows/code_review/add_comments" }
    let(:review_output) do
      <<~REVIEW_OUTPUT.chomp
        <review>
          <step>Thinking process described here.</step>
          <comment file=\"go/server.go\" old_line=\"\" new_line=\"12\">
            The line below in main.go is incorrect.
            <from>http.HandleFunc(\"/hello\", helloHandler)</from>
            <to>http.HandleFunc(\"/hellow\", helloHandler)</to>
          </comment>
        </review>
      REVIEW_OUTPUT
    end

    let(:params) do
      {
        project_id: project.id,
        merge_request_iid: merge_request.iid,
        review_output: review_output
      }
    end

    context 'when successful' do
      include_context 'with DAP Duo Code Review enabled'

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CodeReview::ProcessReviewOutputService) do |service|
          allow(service).to receive_messages(valid?: true, execute: ServiceResponse.success)
        end
      end

      it 'returns success immediately' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['message']).to eq('Comments added successfully')
      end

      context 'when workflow_id is provided' do
        let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
        let(:params_with_workflow) { params.merge(workflow_id: workflow.id) }

        it 'returns success' do
          post api(path, user, oauth_access_token: token), params: params_with_workflow

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end

    context 'when execute fails (e.g. progress note cannot be created)' do
      include_context 'with DAP Duo Code Review enabled'

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CodeReview::ProcessReviewOutputService) do |service|
          allow(service).to receive_messages(valid?: true, execute: ServiceResponse.error(message: ::Gitlab::Duo::CodeReview::Messages.progress_note_not_found_error))
        end
      end

      it 'returns bad request' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to include("Can't create the progress note")
      end
    end

    context 'when validation fails' do
      include_context 'with DAP Duo Code Review enabled'

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CodeReview::ProcessReviewOutputService) do |service|
          allow(service).to receive_messages(valid?: false, message: 'Nothing to review')
        end
      end

      it 'returns bad request without enqueuing a worker' do
        expect(::Ai::DuoWorkflows::CodeReview::PublishCommentsWorker).not_to receive(:perform_async)

        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('400 Bad request - Nothing to review')
      end
    end

    context 'with invalid parameters' do
      include_context 'with DAP Duo Code Review enabled'

      context 'when project_id is missing' do
        let(:params) { { merge_request_iid: merge_request.iid, review_output: review_output } }

        it 'returns bad request' do
          post api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when merge_request_iid is missing' do
        let(:params) { { project_id: project.id, review_output: review_output } }

        it 'returns bad request' do
          post api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('merge_request_iid is missing')
        end
      end

      context 'when review_output is missing' do
        let(:params) { { project_id: project.id, merge_request_iid: merge_request.iid } }

        it 'returns bad request' do
          post api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('review_output is missing')
        end
      end

      context 'when project_id does not exist' do
        let(:params) do
          { project_id: non_existing_record_id, merge_request_iid: merge_request.iid, review_output: review_output }
        end

        it 'returns not found' do
          post api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when project is not found' do
      include_context 'with DAP Duo Code Review enabled'

      let(:params) do
        {
          project_id: 'non-existent',
          merge_request_iid: merge_request.iid,
          review_output: review_output
        }
      end

      it 'returns not found' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when merge request is not found' do
      include_context 'with DAP Duo Code Review enabled'

      let(:params) do
        {
          project_id: project.id,
          merge_request_iid: 9999,
          review_output: review_output
        }
      end

      it 'returns not found', quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24186' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      include_context 'with DAP Duo Code Review enabled'

      it 'returns unauthorized' do
        post api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user does not have access to project' do
      include_context 'with DAP Duo Code Review enabled'

      let_it_be(:unauthorized_user) { create(:user) }
      let_it_be(:unauthorized_service_account) do
        create(:user, :service_account,
          composite_identity_enforced: true,
          organization: organization,
          provisioned_by_group: group
        )
      end

      let(:unauthorized_token) do
        create(:oauth_access_token,
          organization: organization,
          application: oauth_app,
          resource_owner: unauthorized_service_account,
          expires_in: 1.hour,
          scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{unauthorized_user.id}"]
        )
      end

      it 'returns not found (project visibility)' do
        post api(path, unauthorized_user, oauth_access_token: unauthorized_token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Project Not Found')
      end
    end

    context 'when called without composite identity' do
      include_context 'with DAP Duo Code Review enabled'

      it 'returns forbidden' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq(
          '403 Forbidden - This endpoint can only be accessed by Duo Workflow Service'
        )
      end
    end

    context 'when DAP Duo Code Review is disabled' do
      include_context 'with DAP Duo Code Review disabled'

      it 'returns forbidden' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq(
          '403 Forbidden - You are not allowed to use Duo Code Review through Duo Agent Platform'
        )
      end
    end

    context 'with project path instead of ID' do
      include_context 'with DAP Duo Code Review enabled'

      let(:params) do
        {
          project_id: project.full_path,
          merge_request_iid: merge_request.iid,
          review_output: review_output
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CodeReview::CreateCommentsService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
      end

      it 'accepts project path and returns success',
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24188' do
        post api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['message']).to eq('Comments added successfully')
      end
    end

    describe '#verify_composite_identity!' do
      include_context 'with DAP Duo Code Review enabled'

      context 'when service account does not match the toplevel group service account' do
        let_it_be(:mismatched_service_account) do
          create(:user, :service_account, organization: organization)
        end

        let_it_be(:mismatched_token) do
          create(:oauth_access_token,
            organization: organization,
            application: oauth_app,
            resource_owner: mismatched_service_account,
            expires_in: 1.hour,
            scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{user.id}"]
          )
        end

        before_all do
          project.add_developer(mismatched_service_account)
        end

        it 'returns forbidden',
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24189' do
          post api(path, user, oauth_access_token: mismatched_token), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq(
            '403 Forbidden - This endpoint can only be accessed by Duo Workflow Service'
          )
        end
      end

      context 'when service account matches the toplevel group service account' do
        it 'processes the request' do
          post api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/code_review/custom_instructions' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }

    let(:path) { "/ai/duo_workflows/code_review/custom_instructions" }
    let(:params) do
      {
        project_id: project.id,
        merge_request_iid: merge_request.iid
      }
    end

    context 'when successful' do
      include_context 'with DAP Duo Code Review enabled'

      let(:instructions) { [{ name: 'Test', instructions: 'Do something' }] }

      before do
        allow_next_instance_of(::Gitlab::Duo::CodeReview::CustomInstructionsResolver) do |resolver|
          allow(resolver).to receive(:execute).and_return(instructions)
        end
      end

      it 'returns the custom instructions' do
        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['instructions']).to eq(instructions.as_json)
      end
    end

    context 'when verifying resolver invocation' do
      include_context 'with DAP Duo Code Review enabled'

      let(:instructions) { [{ name: 'Test', instructions: 'Do something' }] }

      it 'calls CustomInstructionsResolver with the correct project and merge request' do
        resolver = instance_double(::Gitlab::Duo::CodeReview::CustomInstructionsResolver)
        expect(::Gitlab::Duo::CodeReview::CustomInstructionsResolver)
          .to receive(:new).with(project).and_return(resolver)
        expect(resolver).to receive(:execute).with(merge_request).and_return(instructions)

        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when there are no custom instructions' do
      include_context 'with DAP Duo Code Review enabled'

      before do
        allow_next_instance_of(::Gitlab::Duo::CodeReview::CustomInstructionsResolver) do |resolver|
          allow(resolver).to receive(:execute).and_return([])
        end
      end

      it 'returns an empty instructions array' do
        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['instructions']).to be_empty
      end
    end

    context 'with invalid parameters' do
      include_context 'with DAP Duo Code Review enabled'

      context 'when project_id is missing' do
        let(:params) { { merge_request_iid: merge_request.iid } }

        it 'returns bad request' do
          get api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when merge_request_iid is missing' do
        let(:params) { { project_id: project.id } }

        it 'returns bad request' do
          get api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('merge_request_iid is missing')
        end
      end

      context 'when project_id does not exist' do
        let(:params) { { project_id: non_existing_record_id, merge_request_iid: merge_request.iid } }

        it 'returns not found' do
          get api(path, user, oauth_access_token: token), params: params

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when project is not found' do
      include_context 'with DAP Duo Code Review enabled'

      let(:params) { { project_id: 'non-existent', merge_request_iid: merge_request.iid } }

      it 'returns not found' do
        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when merge request is not found' do
      include_context 'with DAP Duo Code Review enabled'

      let(:params) { { project_id: project.id, merge_request_iid: 9999 } }

      it 'returns not found' do
        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      include_context 'with DAP Duo Code Review enabled'

      it 'returns unauthorized' do
        get api(path), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when DAP Duo Code Review is disabled' do
      include_context 'with DAP Duo Code Review disabled'

      it 'returns ok' do
        get api(path, user, oauth_access_token: token), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when called without composite identity' do
      include_context 'with DAP Duo Code Review enabled'
      it 'returns ok' do
        get api(path, user), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when user does not have access to project' do
      include_context 'with DAP Duo Code Review enabled'

      let_it_be(:unauthorized_user) { create(:user) }
      let_it_be(:unauthorized_service_account) do
        create(:user, :service_account,
          composite_identity_enforced: true,
          organization: organization,
          provisioned_by_group: group
        )
      end

      let(:unauthorized_token) do
        create(:oauth_access_token,
          organization: organization,
          application: oauth_app,
          resource_owner: unauthorized_service_account,
          expires_in: 1.hour,
          scopes: ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{unauthorized_user.id}"]
        )
      end

      it 'returns not found' do
        get api(path, unauthorized_user, oauth_access_token: unauthorized_token), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Project Not Found')
      end
    end
  end
end
