# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.addProjectToSecurityDashboard', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_developer(current_user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'granular PAT authorization' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_dashboard do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) do
        graphql_mutation(:add_project_to_security_dashboard, { id: project.to_global_id.to_s }, 'errors')
      end

      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end
  end
end
