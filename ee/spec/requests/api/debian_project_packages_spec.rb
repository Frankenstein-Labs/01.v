# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DebianProjectPackages, feature_category: :package_registry do
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }
  # rubocop:disable Layout/LineLength
  let_it_be(:distribution) { create(:debian_project_distribution, :with_file, container: project, codename: 'existing-codename') }
  # rubocop:enable Layout/LineLength
  let_it_be(:package) { create(:debian_package, project: project, published_in: distribution) }

  let(:letter) { package.name[0..2] == 'lib' ? package.name[0..3] : package.name[0] }
  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

  describe 'GET projects/:id/packages/debian/pool/:codename/:letter/:package_name/:package_version/:file_name' do
    let(:url) do
      "/projects/#{project.id}/packages/debian/pool/" \
        "#{package.distribution.codename}/#{letter}/#{package.name}/#{package.version}/#{file_name}"
    end

    let(:file_name) { 'sample_1.2.3~alpha2.tar.xz' }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'
  end
end
