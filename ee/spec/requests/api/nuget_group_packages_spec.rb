# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::NugetGroupPackages, feature_category: :package_registry do
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:package_name) { 'Dummy.Package' }
  let_it_be(:package) do
    create(:nuget_package, :with_symbol_package, project: project, name: package_name)
  end

  let_it_be(:version) { package.version }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

  describe 'GET /api/v4/groups/:id/-/packages/nuget/metadata/*package_name/*package_version' do
    let(:url) { "/groups/#{group.id}/-/packages/nuget/metadata/#{package_name}/#{version}.json" }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'

    it_behaves_like 'authorizing granular token permissions', :read_nuget_package do
      let(:boundary_object) { group }
      let(:request) { get api(url), headers: basic_auth_header(user.username, pat.token) }
    end
  end

  describe 'GET /api/v4/groups/:id/-/packages/nuget/metadata/*package_name/index' do
    let_it_be(:packages) do
      create_list(:nuget_package, 5, :with_metadatum, name: package_name, project: project)
    end

    let(:url) { "/groups/#{group.id}/-/packages/nuget/metadata/#{package_name}/index.json" }

    it_behaves_like 'authorizing granular token permissions', :read_nuget_package do
      let(:boundary_object) { group }
      let(:request) { get api(url), headers: basic_auth_header(user.username, pat.token) }
    end
  end

  describe 'GET /api/v4/groups/:id/-/packages/nuget/query' do
    let_it_be(:query_parameters) { { q: 'query', take: 5, skip: 0, prerelease: true } }
    let(:url) { "/groups/#{group.id}/-/packages/nuget/query?#{query_parameters.to_query}" }

    it_behaves_like 'authorizing granular token permissions', :search_nuget_package do
      let(:boundary_object) { group }
      let(:request) { get api(url), headers: basic_auth_header(user.username, pat.token) }
    end
  end
end
