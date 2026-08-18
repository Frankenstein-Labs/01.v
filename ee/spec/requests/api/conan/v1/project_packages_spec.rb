# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Conan::V1::ProjectPackages, feature_category: :package_registry do
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:package) { create(:conan_package, project: project, without_revisions: true) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:package_file) { package.package_files.find_by(file_name: 'conaninfo.txt') }
  let_it_be(:metadata) { package_file.conan_file_metadatum }

  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

  describe "GET /api/v4/projects/:id/packages/conan/v1/files/:package_name/package_version/:package_username" \
    "/:package_channel/:recipe_revision/package/:conan_package_reference/:package_revision/:file_name" do
    let(:url) do
      "/projects/#{project.id}/packages/conan/v1/files/#{package.conan_recipe_path}" \
        "/#{metadata.recipe_revision_value}/package/#{metadata.package_reference_value}" \
        "/#{metadata.package_revision_value}/#{package_file.file_name}"
    end

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'
  end
end
