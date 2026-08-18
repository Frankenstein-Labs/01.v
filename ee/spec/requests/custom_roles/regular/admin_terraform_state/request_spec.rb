# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_terraform_state custom role', feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }

  let_it_be(:role) { create(:member_role, :guest, namespace: project.group, admin_terraform_state: true) }
  let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe Projects::TerraformController do
    describe '#index' do
      it 'user has access via a custom role' do
        get project_terraform_index_path(project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe Mutations::Terraform::State do
    include GraphqlHelpers

    before do
      post_graphql_mutation(mutation, current_user: user)
    end

    context 'when locking a terraform state' do
      let(:state) { create(:terraform_state, project: project) }
      let(:mutation) { graphql_mutation(:terraform_state_lock, id: state.to_global_id.to_s) }

      it_behaves_like 'a working graphql query'
    end

    context 'when unlocking a terraform state' do
      let(:state) { create(:terraform_state, :locked, project: project) }
      let(:mutation) { graphql_mutation(:terraform_state_unlock, id: state.to_global_id.to_s) }

      it_behaves_like 'a working graphql query'
    end

    context 'when deleting a terraform state' do
      let(:state) { create(:terraform_state, project: project) }
      let(:mutation) { graphql_mutation(:terraform_state_delete, id: state.to_global_id.to_s) }

      it_behaves_like 'a working graphql query'
    end
  end
end
