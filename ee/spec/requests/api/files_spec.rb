# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Files, feature_category: :source_code_management do
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  include_context 'for workhorse body uploads'

  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, group: group) }
  let(:file_path) { "files%2Fruby%2Fpopen%2Erb" }
  let(:size_checker) { Namespaces::Storage::RootSize.new(group) }

  before do
    project.add_developer(user)
  end

  def route(file_path = nil)
    "/projects/#{project.id}/repository/files/#{file_path}"
  end

  describe "POST /projects/:id/repository/files/:file_path" do
    let(:file_path) { "new_subfolder%2Fnewfile%2Erb" }
    let(:params) do
      {
        branch: "master",
        content: "puts 8",
        commit_message: "Added newfile"
      }
    end

    context 'with an exceeded namespace storage limit', :saas do
      before do
        # Use create_or_replace_subscription because project.add_developer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate)
        create(:namespace_root_storage_statistics, namespace: group)
        enforce_namespace_storage_limit(group)
        set_enforcement_limit(group, megabytes: 5)
        set_used_storage(group, megabytes: 6)
      end

      it 'rejects the request' do
        workhorse_body_upload(api(route(file_path), user), params)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end

  describe "PUT /projects/:id/repository/files/:file_path" do
    let(:method) { :put }
    let(:params) do
      {
        branch: 'master',
        content: 'puts 8',
        commit_message: 'Change file'
      }
    end

    context 'with an exceeded namespace storage limit', :saas do
      before do
        # Use create_or_replace_subscription because project.add_developer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate)
        create(:namespace_root_storage_statistics, namespace: group)
        enforce_namespace_storage_limit(group)
        set_enforcement_limit(group, megabytes: 5)
        set_used_storage(group, megabytes: 6)
      end

      it 'rejects the request' do
        workhorse_body_upload(api(route(file_path), user), params)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end

  describe "DELETE /projects/:id/repository/files/:file_path" do
    let(:params) do
      {
        branch: 'master',
        commit_message: 'Delete file'
      }
    end

    context 'with an exceeded namespace storage limit', :saas do
      before do
        # Use create_or_replace_subscription because project.add_developer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate)
        create(:namespace_root_storage_statistics, namespace: group)
        enforce_namespace_storage_limit(group)
        set_enforcement_limit(group, megabytes: 5)
        set_used_storage(group, megabytes: 6)
      end

      it 'rejects the request' do
        delete api(route(file_path), user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end
end
