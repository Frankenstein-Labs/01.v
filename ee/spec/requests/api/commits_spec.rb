# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Commits, feature_category: :source_code_management do
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, creator: user, path: "my.project") }
  let(:size_checker) { Namespaces::Storage::RootSize.new(namespace) }
  let(:project_id) { project.id }

  before do
    project.add_maintainer(user)
  end

  shared_examples_for "handling the codeowners interaction" do
    it "does not create a new check" do
      expect(Gitlab::Checks::Diffs::CodeOwnersCheck)
        .not_to receive(:new)

      subject
    end
  end

  describe "POST /projects/:id/repository/commits" do
    include_context 'for workhorse body uploads'

    let!(:url) { api("/projects/#{project_id}/repository/commits", user) }

    context "create" do
      let(:message) { "Created a new file with a very very looooooooooooooooooooooooooooooooooooooooooooooong commit message" }
      let(:file_path) { "foo/bar/baz.txt" }
      let(:valid_c_params) do
        {
          branch: "master",
          commit_message: message,
          actions: [
            {
              action: "create",
              file_path: file_path,
              content: "puts 8"
            }
          ]
        }
      end

      context "a new file that does not match a codeowners entry" do
        before do
          perform_workhorse_json_body_upload(url, valid_c_params.to_json)
        end

        it "creates the commit" do
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq(message)
          expect(json_response['committer_name']).to eq(user.name)
          expect(json_response['committer_email']).to eq(user.email)
        end
      end

      context "a new file that matches a codeowner entry" do
        context "when codeowners are required" do
          let(:code_owner_approval_required) { true }
          let(:params) { valid_c_params }
          let(:branch) { valid_c_params[:branch] }
          let(:paths)  { valid_c_params[:actions].first[:file_path] }

          it_behaves_like "handling the codeowners interaction"
        end
      end

      context "with composite identity" do
        before do
          project.add_developer(service_account)

          perform_workhorse_json_body_upload(url, valid_c_params.to_json)
        end

        let(:organization) { create(:organization) }
        let(:oauth_app) { create(:doorkeeper_application) }
        let(:scopes) { ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{user.id}"] }

        let(:service_account) do
          create(:user, :service_account, composite_identity_enforced: true, organization: organization, organizations: [organization, project.organization])
        end

        let(:token) do
          create(:oauth_access_token, {
            organization: organization,
            application: oauth_app,
            resource_owner: service_account,
            expires_in: 1.hour,
            scopes: scopes
          })
        end

        let!(:url) { api("/projects/#{project_id}/repository/commits", user, oauth_access_token: token) }

        let(:file_path) { "foo/bar/1.txt" }

        it 'attributes the commit author to the service account' do
          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq(message)
          expect(json_response['committer_name']).to eq(service_account.name)
          expect(json_response['committer_email']).to eq(service_account.email)
        end
      end
    end

    context "delete" do
      let(:message) { "Deleted file" }
      let(:valid_d_params) do
        {
          branch: "markdown",
          commit_message: message,
          actions: [
            {
              action: "delete",
              file_path: "doc/api/users.md"
            }
          ]
        }
      end

      context "a deleted file that does not match a codeowner entry" do
        it "creates the commit" do
          perform_workhorse_json_body_upload(url, valid_d_params.to_json)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq(message)
        end
      end

      context "a deleted file that matches a codeowner entry" do
        let(:code_owner_approval_required) { true }
        let(:params) { valid_d_params }
        let(:branch) { valid_d_params[:branch] }
        let(:paths)  { valid_d_params[:actions].first[:file_path] }

        it_behaves_like "handling the codeowners interaction"
      end
    end

    describe "move" do
      let(:message) { "Moved file" }
      let(:valid_m_params) do
        {
          branch: "feature",
          commit_message: message,
          actions: [
            {
              action: "move",
              file_path: "VERSION.txt",
              previous_path: "VERSION",
              content: "6.7.0.pre"
            }
          ]
        }
      end

      context "a deleted file that does not match a codeowner entry" do
        it "creates the commit" do
          perform_workhorse_json_body_upload(url, valid_m_params.to_json)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['title']).to eq(message)
        end
      end

      context "a moved file that matches a codeowner entry" do
        let(:code_owner_approval_required) { true }
        let(:params) { valid_m_params }
        let(:branch) { valid_m_params[:branch] }
        let(:paths) do
          action = valid_m_params[:actions].first
          [action[:file_path], action[:previous_path]]
        end

        it_behaves_like "handling the codeowners interaction"
      end
    end
  end

  describe "POST :id/repository/commits/:sha/cherry_pick" do
    let(:commit)    { project.commit("7d3b0f7cff5f37573aea97cebfd5692ea1689924") }
    let(:commit_id) { commit.id }
    let(:branch)    { "master" }
    let(:route)     { "/projects/#{project_id}/repository/commits/#{commit_id}/cherry_pick" }

    subject(:request) { post api(route, user), params: { branch: branch } }

    context "no file in the cherry-picked commit matches a codeowner entry" do
      it "cherry-picks the ref commit" do
        post api(route, user), params: { branch: branch }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema("public_api/v4/commit/basic")
        expect(json_response["title"]).to eq(commit.title)
        expect(json_response["message"]).to eq(
          "#{commit.cherry_pick_message(user)}\n\nCo-authored-by: #{commit.author_name} <#{commit.author_email}>"
        )
        expect(json_response["author_name"]).to eq(user.name)
        expect(json_response["committer_name"]).to eq(user.name)
      end
    end

    context "a file in the cherry-picked commit matches a codeowner entry" do
      context "when codeowners are required" do
        let(:code_owner_approval_required) { true }
        let(:paths) { commit.raw_deltas.flat_map { |diff| [diff.new_path, diff.old_path] }.uniq }

        it_behaves_like "handling the codeowners interaction"
      end
    end

    context 'with an exceeded namespace storage limit', :saas do
      let(:namespace) { project.namespace }

      before do
        # Use create_or_replace_subscription because project.add_maintainer (line 14)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(namespace, :ultimate)
        create(:namespace_root_storage_statistics, namespace: namespace)
        enforce_namespace_storage_limit(namespace)
        set_enforcement_limit(namespace, megabytes: 5)
        set_used_storage(namespace, megabytes: 6)
      end

      it "rejects the request" do
        post api(route, user), params: { branch: branch }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end

  describe "POST :id/repository/commits/:sha/revert" do
    let_it_be(:project) { create(:project, :repository, creator: user, path: "my.project") }

    let(:commit_id) { 'b83d6e391c22777fca1ed3012fce84f633d7fed0' }
    let(:commit)    { project.commit(commit_id) }
    let(:branch)    { 'master' }
    let(:route)     { "/projects/#{project_id}/repository/commits/#{commit_id}/revert" }

    subject(:request) { post api(route, user), params: { branch: branch } }

    context "no file in the revert commit matches a codeowner entry" do
      it "reverts the ref commit" do
        post api(route, user), params: { branch: branch }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/commit/basic')

        expect(json_response['message']).to eq(commit.revert_message(user))
        expect(json_response['author_name']).to eq(user.name)
        expect(json_response['committer_name']).to eq(user.name)
        expect(json_response['parent_ids']).to contain_exactly(commit_id)
      end
    end

    context "a file in the revert commit matches a codeowner entry" do
      context "when codeowners are required" do
        let(:code_owner_approval_required) { true }
        let(:paths) { commit.raw_deltas.flat_map { |diff| [diff.new_path, diff.old_path] }.uniq }

        it_behaves_like "handling the codeowners interaction"
      end
    end

    context 'with an exceeded namespace storage limit', :saas do
      let(:namespace) { project.namespace }

      before do
        # Use create_or_replace_subscription because project.add_maintainer (line 14)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(namespace, :ultimate)
        create(:namespace_root_storage_statistics, namespace: namespace)
        enforce_namespace_storage_limit(namespace)
        set_enforcement_limit(namespace, megabytes: 5)
        set_used_storage(namespace, megabytes: 6)
      end

      it "rejects the request" do
        post api(route, user), params: { branch: branch }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end
end
