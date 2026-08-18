# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe "Validating a devfile", feature_category: :workspaces do
  include GraphqlHelpers
  include StubFeatureFlags
  include_context "with remote development shared fixtures"

  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user }
  let(:devfile_yaml) { " " }

  let(:mutation) do
    graphql_mutation(:devfile_validate, mutation_args)
  end

  let(:all_mutation_args) do
    {
      devfile_yaml: devfile_yaml
    }
  end

  let(:mutation_args) { all_mutation_args }

  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::DevfileOperations::Main,
      domain_main_class_args: {
        devfile_yaml: devfile_yaml,
        user: current_user
      }
    }
  end

  def mutation_response
    graphql_mutation_response(:devfile_validate)
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context "when devfile is valid" do
    let(:stub_service_response) { ServiceResponse.success(message: "Validation Success") }

    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
        stub_service_response
      end
    end

    it "returns empty array and valid status" do
      post_graphql_mutation(mutation, current_user: user)

      expect_graphql_errors_to_be_empty
      expect(mutation_response["valid"]).to be true
    end
  end

  context "when a devfile is invalid" do
    let(:stub_service_response) { ServiceResponse.error(message: "Validation Error", reason: :bad_request) }

    before do
      allow(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
        stub_service_response
      end
    end

    it_behaves_like "a mutation that returns errors in the response", errors: ["Validation Error"]

    it "asserts valid key is false" do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response["valid"]).to be false
    end
  end

  context "when devfile argument is missing" do
    let(:mutation_args) { all_mutation_args.except(:devfile_yaml) }

    it "returns error about required argument" do
      post_graphql_mutation(mutation, current_user: current_user)

      expect_graphql_errors_to_include(/provided invalid value for devfileYaml \(Expected value to not be null\)/)
    end
  end

  context "when remote_development feature is unlicensed" do
    before do
      stub_licensed_features(remote_development: false)
    end

    it_behaves_like "a mutation that returns top-level errors" do
      let(:match_errors) { include(/'remote_development' licensed feature is not available/) }
    end
  end
end
