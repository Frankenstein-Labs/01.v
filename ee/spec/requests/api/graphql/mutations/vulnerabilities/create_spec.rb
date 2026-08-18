# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mutation.vulnerabilityCreate", feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:mutation) { graphql_mutation(:vulnerability_create, arguments) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let(:arguments) do
    {
      project: project.to_global_id,
      name: "Test vulnerability",
      description: "Test vulnerability created via GraphQL",
      scanner: {
        id: "my-custom-scanner",
        name: "My Custom Scanner",
        url: "https://superscanner.com",
        vendor: { name: "Custom Scanner Vendor" },
        version: "21.37.00"
      },
      identifiers: [{
        name: "Test identifier",
        url: "https://vulnerabilities.com/test"
      }],
      state: "DETECTED",
      severity: "UNKNOWN",
      solution: "rm -rf --no-preserve-root /"
    }
  end

  let(:mutation_response) { graphql_mutation_response(:vulnerability_create) }

  context "with a Maintainer role" do
    let(:at) { Time.new(2020, 6, 21, 14, 22, 20) }

    before_all do
      project.add_maintainer(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it "returns a successful response" do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response["vulnerability"]).to be_present
      expect(mutation_response["vulnerability"]["state"]).to eq("DETECTED")
      expect(mutation_response["vulnerability"]["description"]).to eq(arguments[:description])
      expect(mutation_response["vulnerability"]["solution"]).to eq(arguments[:solution])
      expect(mutation_response["errors"]).to be_empty
    end

    context "when confirming a vulnerability" do
      let(:arguments) { super().merge(state: "CONFIRMED", confirmed_at: at) }

      it "returns a successful response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response["vulnerability"]).to be_present
        expect(mutation_response["vulnerability"]["state"]).to eq("CONFIRMED")
        expect(mutation_response["vulnerability"]["confirmedAt"]).to eq(at.utc.iso8601)
        expect(mutation_response.dig("vulnerability", "confirmedBy", "id")).to eq(current_user.to_global_id.to_s)
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "when resolving a vulnerability" do
      let(:arguments) { super().merge(state: "RESOLVED", resolved_at: at) }

      it "returns a successful response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response["vulnerability"]).to be_present
        expect(mutation_response["vulnerability"]["state"]).to eq("RESOLVED")
        expect(mutation_response["vulnerability"]["resolvedAt"]).to eq(at.utc.iso8601)
        expect(mutation_response.dig("vulnerability", "resolvedBy", "id")).to eq(current_user.to_global_id.to_s)
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "when dismissing a vulnerability" do
      let(:arguments) { super().merge(state: "DISMISSED", dismissed_at: at) }

      it "returns a successful response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response["vulnerability"]).to be_present
        expect(mutation_response["vulnerability"]["state"]).to eq("DISMISSED")
        expect(mutation_response["vulnerability"]["dismissedAt"]).to eq(at.utc.iso8601)
        expect(mutation_response.dig("vulnerability", "dismissedBy", "id")).to eq(current_user.to_global_id.to_s)
        expect(mutation_response["errors"]).to be_empty
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_vulnerability do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) { graphql_mutation(:vulnerability_create, arguments, 'errors') }
      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end
  end

  context "with an unauthorized role" do
    before_all do
      project.add_guest(current_user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it "returns an empty response" do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response).to be_blank
    end

    it "does not create a new vulnerability" do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.not_to change { Vulnerability.count }
    end
  end

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
        expect(mutation_response["vulnerability"]).to be_present
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "with `admin_vulnerability` disabled" do
      let(:role) { create(:member_role, :guest, namespace: project.group) }

      it "returns an empty response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response).to be_nil
      end
    end
  end
end
