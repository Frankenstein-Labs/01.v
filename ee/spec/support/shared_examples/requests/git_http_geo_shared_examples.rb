# frozen_string_literal: true

# Shared examples for Git HTTP Geo project repository replication behavior.
#
# This shared example tests how Git HTTP requests are handled on a Geo secondary
# for project repositories, including redirects to primary when out of date.
#
# Required variables (must be defined in the including spec):
#
# - project_with_repo: A project with a repository
#   Example: let(:project_with_repo) { create(:project, :repository) }
#
# - project_registry_with_repo: A Geo registry for the project
#   Example: let(:project_registry_with_repo) { create(:geo_project_repository_registry, project: project_with_repo) }
#
# - user: A user for authentication
#   Example: let(:user) { create(:user) }
#
# - full_redirected_url: The expected redirect URL to primary
#   Example: let(:full_redirected_url) { "https://primary.example.com/..." }
#
RSpec.shared_examples 'http requests tests for project repository sync' do
  let_it_be(:project, freeze: false) { project_with_repo }
  let(:auth_header) { auth_env(user.username, user.password, nil) }

  context 'when the repository exists' do
    context 'and has not successfully synced' do
      let(:redirect_url) { full_redirected_url }

      before do
        # Create a registry with no sync time for this specific test
        # create(:geo_project_repository_registry, project: project, last_synced_at: nil)
        project_registry_with_repo.update!(last_synced_at: nil)
      end

      it_behaves_like 'a Geo 302 redirect to Primary'
    end

    context 'and has successfully synced' do
      it_behaves_like 'a 200 git request'
    end
  end

  context 'when repository is up to date' do
    before do
      # Mock that repository is up to date - serve locally
      allow(::Geo::ProjectRepositoryRegistry)
        .to receive(:repository_out_of_date?)
        .and_return(false)
    end

    it 'serves the repository locally when up to date' do
      get "/#{project.full_path}.git/info/refs", params: { service: 'git-upload-pack' }, headers: auth_header

      expect(response).to have_gitlab_http_status(:ok)
      # Verify the method was called (with any identifier)
      expect(::Geo::ProjectRepositoryRegistry).to have_received(:repository_out_of_date?)
        .at_least(:once)
    end
  end

  context 'when repository is out of date' do
    before do
      # Mock that repository is out of date - should redirect to primary
      allow(::Geo::ProjectRepositoryRegistry)
        .to receive(:repository_out_of_date?)
        .and_return(true)
    end

    it 'redirects to primary when repository is out of date' do
      get "/#{project.full_path}.git/info/refs", params: { service: 'git-upload-pack' }, headers: auth_header

      # When out of date, Geo redirects to primary (this is correct behavior)
      expect(response).to have_gitlab_http_status(:redirect)
      expect(response.location).to include('from_secondary')
    end
  end
end
