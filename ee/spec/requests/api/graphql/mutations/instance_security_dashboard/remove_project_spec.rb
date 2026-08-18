# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Mutation.removeProjectFromSecurityDashboard', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before_all do
    project.add_developer(current_user)
    current_user.security_dashboard_projects << project
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'granular PAT authorization' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_dashboard do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) do
        graphql_mutation(:remove_project_from_security_dashboard, { id: project.to_global_id.to_s }, 'errors')
      end

      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end
  end
end
