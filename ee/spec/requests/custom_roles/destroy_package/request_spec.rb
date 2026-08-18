# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with destroy_package custom role', feature_category: :package_registry do
  let_it_be(:project, freeze: false) { create(:project, :in_group) }
  let_it_be(:group) { project.group }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:role) { create(:member_role, :developer, namespace: group, destroy_package: true) }

  let(:package) { create(:generic_package, project: project) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  shared_examples 'destroying a package via the custom role' do
    describe API::ProjectPackages do
      include ApiHelpers

      it 'allows a user with the custom role to delete a package', :aggregate_failures do
        package

        expect do
          delete api("/projects/#{project.id}/packages/#{package.id}", user)
        end.to change { ::Packages::Package.pending_destruction.count }.by(1)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    describe Mutations::Packages::Destroy do
      include GraphqlHelpers

      let(:mutation) { graphql_mutation(:destroy_package, id: package.to_global_id.to_s) }

      it 'destroys the package via the custom role', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_mutation_response(:destroy_package)['errors']).to be_empty
        expect(package.reload).to be_pending_destruction
      end
    end
  end

  context 'when the user is a project member' do
    let_it_be(:member) { create(:project_member, :developer, member_role: role, user: user, project: project) }

    it_behaves_like 'destroying a package via the custom role'
  end

  context 'when the user is a group member' do
    let_it_be(:member) { create(:group_member, :developer, member_role: role, user: user, source: group) }

    it_behaves_like 'destroying a package via the custom role'
  end

  context 'when the user does not have the custom permission' do
    include ApiHelpers

    let_it_be(:developer) { create(:user, developer_of: project) }

    it 'denies deleting the package', :aggregate_failures do
      package

      expect do
        delete api("/projects/#{project.id}/packages/#{package.id}", developer)
      end.not_to change { ::Packages::Package.pending_destruction.count }

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end
end
