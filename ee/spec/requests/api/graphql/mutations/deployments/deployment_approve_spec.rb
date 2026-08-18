# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Approve a deployment', feature_category: :environment_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:environment) { create(:environment, :staging, project: project) }
  let_it_be(:protected_environment) { create(:protected_environment, name: environment.name, project: project) }
  let_it_be(:protected_environment_approval_rule) do
    create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment)
  end

  before do
    stub_licensed_features(protected_environments: true)
  end

  context 'with project permissions' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :approve_deployment do
      let(:deployment) do
        create(:deployment, :blocked, user: developer, project: project, environment: environment)
      end

      let(:user) { maintainer }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:approve_deployment,
          { id: deployment.to_global_id.to_s, status: 'APPROVED' }, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
