# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::AgentValidator, feature_category: :workspaces do
  include ResultMatchers

  # @param [Group] namespace
  # @return [Clusters::Agent]
  def create_agent_in_namespace(namespace:)
    agent_project = create(:project, :public, developers: user, namespace: namespace).tap do |project|
      project.add_developer(user)
    end

    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:workspace_ancestor_namespace) { create(:group, parent: root_namespace) }
  let_it_be_with_reload(:workspace_project) do
    create(:project, :public, developers: user, namespace: workspace_ancestor_namespace)
      .tap do |project|
      project.add_developer(user)
    end
  end

  let(:params) do
    {
      agent: agent,
      project: workspace_project
    }
  end

  let(:context) do
    {
      params: params
    }
  end

  subject(:result) do
    described_class.validate(context)
  end

  context "when an agent is valid" do
    context "when the agent is organization mapped" do
      let(:agent) do
        # noinspection RubyMismatchedArgumentType -- RubyMine is incorrecly resolving QA::Resource::Group as type
        agent = create_agent_in_namespace(namespace: root_namespace)
        create(
          :organization_cluster_agent_mapping,
          user: user,
          agent: agent,
          organization: agent.project.organization
        )
        agent
      end

      it "returns an ok Result containing the original params" do
        expect(result).to eq(Gitlab::Fp::Result.ok({ params: params }))
      end
    end

    context "when the agent is namespace mapped" do
      let(:agent) do
        agent = create_agent_in_namespace(namespace: workspace_ancestor_namespace)
        create(
          :namespace_cluster_agent_mapping,
          user: user,
          agent: agent,
          namespace: workspace_ancestor_namespace
        )
        agent
      end

      it "returns an ok Result containing the original params" do
        expect(result).to eq(Gitlab::Fp::Result.ok({ params: params }))
      end
    end
  end

  context "when the agent is invalid" do
    shared_examples "invalid agent" do
      it "returns a WorkspaceCreateParamsValidationFailed error with the expected message" do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateParamsValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details)
            .to eq(expected_error_message)
        end
      end
    end

    context "when the agent is not organization mapped" do
      context "when the agent is not mapped to an ancestor namespace of the workspace project" do
        let(:agent) do
          create_agent_in_namespace(namespace: workspace_ancestor_namespace)
        end

        let(:expected_error_message) do
          "Cannot use agent '#{agent.name}' as an organization mapped agent, " \
            "the provided agent is not mapped in organization '#{workspace_project.organization.name}'" \
            ". It also cannot be used as a namespace mapped agent, it " \
            "is not mapped to an ancestor namespace of the workspaces' project."
        end

        it_behaves_like "invalid agent"
      end

      context "when the agent does not reside within the hierarchy of any of the mapped ancestor namespaces" do
        let(:agent) do
          # noinspection RubyMismatchedArgumentType -- RubyMine is incorrecly resolving QA::Resource::Group as type
          agent = create_agent_in_namespace(namespace: root_namespace)
          create(
            :namespace_cluster_agent_mapping,
            user: user,
            agent: agent,
            namespace: workspace_ancestor_namespace
          )
          agent
        end

        let(:expected_error_message) do
          "Cannot use agent '#{agent.name}' as an organization mapped agent, the provided agent " \
            "is not mapped in organization '#{workspace_project.organization.name}'. It also cannot be used " \
            "as a namespace mapped agent, 1 mapping(s) exist between the provided agent " \
            "and the ancestor namespaces of the workspaces' project, but the agent does not reside within the " \
            "hierarchy of any of the mapped ancestor namespaces."
        end

        it_behaves_like "invalid agent"
      end
    end
  end
end
