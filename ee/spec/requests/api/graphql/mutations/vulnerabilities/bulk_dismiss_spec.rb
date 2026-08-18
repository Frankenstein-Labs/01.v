# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mutation.vulnerabilitiesDismiss", feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:vulnerability_1) { create(:vulnerability, :with_findings, project: project) }
  let_it_be(:vulnerability_2) { create(:vulnerability, :with_findings, project: project) }

  let(:vulnerabilities) { [vulnerability_1, vulnerability_2] }
  let(:vulnerability_ids) { vulnerabilities.map { |v| v.to_global_id.to_s } }
  let(:comment) { 'Dismissal Feedback' }
  let(:dismissal_reason) { 'USED_IN_TESTS' }
  let(:arguments) do
    {
      vulnerability_ids: vulnerability_ids,
      comment: comment,
      dismissal_reason: dismissal_reason
    }
  end

  subject(:mutation) { graphql_mutation(:vulnerabilities_dismiss, arguments) }

  def mutation_response
    graphql_mutation_response(:vulnerabilities_dismiss)
  end

  context "when the user does not have access" do
    it_behaves_like "a mutation that returns a top-level access error"
  end

  context "when the user has access" do
    before_all do
      project.add_maintainer(current_user)
    end

    context "when security_dashboard is disabled" do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: ['The resource that you are attempting to access does not ' \
                 'exist or you don\'t have permission to perform this action']
    end

    context "when security_dashboard is enabled" do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      it "dismisses the vulnerabilities" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(vulnerability_1.reload).to be_dismissed
        expect(vulnerability_2.reload).to be_dismissed
        expect(mutation_response["errors"]).to be_empty
        expect(mutation_response["vulnerabilities"].count).to eq(2)
        mutation_response["vulnerabilities"].each do |vulnerability|
          expect(vulnerability["state"]).to eq("DISMISSED")
          expect(vulnerability["stateComment"]).to eq(comment)
          expect(vulnerability["dismissedBy"]["id"]).to eq(current_user.to_global_id.to_s)
        end
      end

      context "without a comment" do
        let(:arguments) do
          {
            vulnerability_ids: vulnerability_ids,
            dismissal_reason: dismissal_reason
          }
        end

        it "dismisses the vulnerabilities" do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(vulnerability_1.reload).to be_dismissed
          expect(vulnerability_2.reload).to be_dismissed
          expect(mutation_response["errors"]).to be_empty
        end
      end

      context "without a dismissal reason" do
        let(:arguments) do
          {
            vulnerability_ids: vulnerability_ids,
            comment: comment
          }
        end

        it "dismisses the vulnerabilities" do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(vulnerability_1.reload).to be_dismissed
          expect(vulnerability_2.reload).to be_dismissed
          expect(mutation_response["errors"]).to be_empty
        end
      end

      context "when too many vulnerabilities are passed" do
        let(:vulnerability_ids) do
          Array.new(::Mutations::Vulnerabilities::CreateIssue::MAX_VULNERABILITIES + 1) do
            'gid://gitlab/Vulnerability/1'
          end
        end

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ["vulnerabilityIds is too long (maximum is 100)"]
      end

      context "when vulnerability_id is nil" do
        let(:vulnerability_ids) { [nil] }

        it_behaves_like 'a mutation that returns top-level errors', errors: [/Expected value to not be null/]
      end

      context "when vulnerability_ids are empty" do
        let(:vulnerability_ids) { [] }

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ["vulnerabilityIds is too short (minimum is 1)"]
      end
    end
  end

  context "with a custom role" do
    before do
      stub_licensed_features(security_dashboard: true, custom_roles: true)
      group = project.group
      role = create(:member_role, :guest, admin_vulnerability: enabled, read_vulnerability: enabled, namespace: group)
      create(:project_member, :guest, user: current_user, source: project, member_role: role)
    end

    context "with `admin_vulnerability` enabled" do
      let(:enabled) { true }

      it "returns a successful response with vulnerabilities" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response["vulnerabilities"]).to be_present
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "with `admin_vulnerability` disabled" do
      let(:enabled) { false }

      it "returns an empty response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response).to be_nil
      end
    end
  end
end
