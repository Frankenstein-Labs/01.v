# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mutation.vulnerabilityResolve", feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, project: project) }

  let(:arguments) do
    {
      id: vulnerability.to_global_id.to_s,
      comment: "resolved"
    }
  end

  subject(:mutation) { graphql_mutation(:vulnerability_resolve, arguments) }

  context "with a custom role" do
    let!(:membership) { create(:project_member, :guest, user: current_user, source: project, member_role: role) }

    before do
      stub_licensed_features(security_dashboard: true, custom_roles: true)
    end

    context "with `admin_vulnerability` enabled" do
      let(:role) { create(:member_role, :guest, :admin_vulnerability, namespace: project.group) }

      it "returns a successful response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        mutation_response = graphql_mutation_response(:vulnerability_resolve)
        expect(mutation_response["vulnerability"]).to be_present
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "with `admin_vulnerability` disabled" do
      let(:role) { create(:member_role, :guest, namespace: project.group) }

      it "returns an empty response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_mutation_response(:vulnerability_resolve)).to be_nil
      end
    end
  end

  describe 'granular PAT authorization' do
    before_all do
      project.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :resolve_vulnerability do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) { graphql_mutation(:vulnerability_resolve, arguments, 'errors') }
      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end
  end
end
