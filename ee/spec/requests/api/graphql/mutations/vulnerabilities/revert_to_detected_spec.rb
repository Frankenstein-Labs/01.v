# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mutation.vulnerabilityRevertToDetected", feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :dismissed, project: project) }

  let(:arguments) do
    {
      id: vulnerability.to_global_id.to_s,
      comment: "Reverting to detected"
    }
  end

  describe 'granular PAT authorization' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :revert_vulnerability do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) { graphql_mutation(:vulnerability_revert_to_detected, arguments, 'errors') }
      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end
  end
end
