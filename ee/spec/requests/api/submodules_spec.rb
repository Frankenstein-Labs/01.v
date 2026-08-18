# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Submodules, feature_category: :source_code_management do
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, group: group) }
  let(:submodule) { 'six' }

  let(:params) do
    {
      submodule: submodule,
      commit_sha: 'e25eda1fece24ac7a03624ed1320f82396f35bd8',
      branch: 'master',
      commit_message: 'update submodule'
    }
  end

  before do
    project.add_developer(user)
  end

  def route(submodule)
    "/projects/#{project.id}/repository/submodules/#{submodule}"
  end

  describe "PUT /projects/:id/repository/submodule/:submodule" do
    context 'with an exceeded namespace storage limit', :saas do
      let(:size_checker) { Namespaces::Storage::RootSize.new(group) }

      before do
        # Use create_or_replace_subscription because project.add_developer (line 23)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate)
        create(:namespace_root_storage_statistics, namespace: group)
        enforce_namespace_storage_limit(group)
        set_enforcement_limit(group, megabytes: 4)
        set_used_storage(group, megabytes: 5)
      end

      it 'rejects the request' do
        put api(route(submodule), user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq(size_checker.error_message.commit_error)
      end
    end
  end
end
