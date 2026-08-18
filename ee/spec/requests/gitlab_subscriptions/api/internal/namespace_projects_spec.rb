# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::NamespaceProjects, :saas, :aggregate_failures, :api, feature_category: :subscription_management do
  include GitlabSubscriptions::InternalApiHelpers

  let_it_be(:namespace) { create(:group) }

  def namespace_projects_path(namespace_id)
    internal_api("namespaces/#{namespace_id}/projects")
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:id/projects' do
    context 'when unauthenticated' do
      it 'returns an error response' do
        get namespace_projects_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get namespace_projects_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the namespace has no projects' do
        it 'returns an empty response' do
          get namespace_projects_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when the namespace has projects' do
        let_it_be(:public_project) { create(:project, :public, :repository, namespace: namespace) }
        let_it_be(:private_project) { create(:project, :private, namespace: namespace) }
        let_it_be(:empty_public_project) { create(:project, :public, namespace: namespace) }
        let_it_be(:empty_public_project_no_wiki) do
          create(:project, :public, :wiki_disabled, namespace: namespace)
        end

        let_it_be(:sub_group) { create(:group, parent: namespace) }
        let_it_be(:sub_group_project) { create(:project, :public, :repository, namespace: sub_group) }

        it 'returns projects from the namespace and its subgroups' do
          get namespace_projects_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.pluck('id')).to match_array(
            [
              public_project.id, private_project.id, empty_public_project.id,
              empty_public_project_no_wiki.id, sub_group_project.id
            ]
          )
        end

        it 'includes visibility and repository metadata for each project' do
          get namespace_projects_path(namespace.id), headers: internal_api_headers

          project_json = json_response.find { |p| p['id'] == public_project.id }

          expect(project_json).to include(
            'id' => public_project.id,
            'path_with_namespace' => public_project.full_path,
            'web_url' => public_project.web_url,
            'visibility' => 'public',
            'empty_repo' => false,
            'wiki_enabled' => true
          )
        end

        it 'only includes license data for public, non-empty projects' do
          get namespace_projects_path(namespace.id), headers: internal_api_headers

          private_project_json = json_response.find { |p| p['id'] == private_project.id }
          empty_public_project_json = json_response.find { |p| p['id'] == empty_public_project.id }
          empty_public_project_no_wiki_json = json_response.find { |p| p['id'] == empty_public_project_no_wiki.id }
          public_project_json = json_response.find { |p| p['id'] == public_project.id }

          expect(private_project_json).not_to have_key('license')
          expect(empty_public_project_json).not_to have_key('license')
          # Regression test: an empty repo with the wiki disabled must still skip license
          # detection (previously only skipped when empty *and* wiki-enabled).
          expect(empty_public_project_no_wiki_json).not_to have_key('license')
          expect(public_project_json).to have_key('license')
        end

        it 'paginates the response' do
          get namespace_projects_path(namespace.id), params: { per_page: 2 }, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(2)
          expect(response.headers['X-Per-Page']).to eq('2')
        end
      end
    end
  end
end
