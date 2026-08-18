# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspacesFinder, feature_category: :workspaces do
  include_context "with constant modules"

  let_it_be(:common_organization) { create(:common_organization) }
  let_it_be(:group) { create(:group, organization: common_organization) }
  let_it_be(:agents_project) { create(:project, namespace: group) }

  let_it_be(:current_user) { create(:user) }

  let_it_be(:cluster_admin_user) { create(:user) }
  let_it_be(:agent_a) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, created_by_user: cluster_admin_user,
      project: agents_project)
  end

  let_it_be(:agent_b) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, created_by_user: cluster_admin_user,
      project: agents_project)
  end

  let_it_be(:workspace_owner_user) { create(:user) }
  let_it_be(:project_a) { create(:project, :public, namespace: group) }
  let_it_be(:project_b) { create(:project, :public, namespace: group) }
  let_it_be(:project_c) { create(:project, :public, namespace: group) }
  let_it_be(:workspace_a) do
    create(:workspace, user: workspace_owner_user, updated_at: 2.days.ago, project: project_a,
      actual_state: states_module::RUNNING, agent: agent_a
    )
  end

  let_it_be(:workspace_b) do
    create(:workspace, user: workspace_owner_user, updated_at: 1.day.ago, project: project_b,
      actual_state: states_module::TERMINATED, agent: agent_b
    )
  end

  let_it_be(:other_user) { create(:user) }
  let_it_be(:other_users_workspace) do
    create(:workspace, user: other_user, project_id: project_c.id,
      actual_state: states_module::TERMINATED, agent: agent_b
    )
  end

  subject(:collection_proxy) do
    # noinspection RubyMismatchedArgumentType -- We are passing a QA::Resource::User test double
    described_class.execute(current_user: current_user, **filter_arguments)
  end

  before do
    stub_licensed_features(remote_development: true)
    allow(::RemoteDevelopment::FilterArgumentValidator).to receive_messages(validate_filter_argument_types!: true,
      validate_at_least_one_filter_argument_provided!: true)
  end

  context "with ids argument" do
    let(:filter_arguments) { { ids: [workspace_a.id] } }

    it "returns only current user's workspaces matching the specified IDs" do
      expect(collection_proxy).to contain_exactly(workspace_a)
      expect(collection_proxy).not_to include(other_users_workspace)
    end
  end

  context "with user_ids argument" do
    let(:filter_arguments) { { user_ids: [workspace_owner_user.id] } }

    it "returns only workspaces matching the specified user_ids" do
      expect(collection_proxy).to contain_exactly(workspace_b, workspace_a)
    end
  end

  context "with project_ids argument" do
    let(:filter_arguments) { { project_ids: [project_a.id] } }

    it "returns only workspaces matching the specified project IDs" do
      expect(collection_proxy).to contain_exactly(workspace_a)
    end
  end

  context "with agent_ids argument" do
    let(:filter_arguments) { { agent_ids: [agent_a.id] } }

    it "returns only workspaces matching the specified agent IDs" do
      expect(collection_proxy).to contain_exactly(workspace_a)
    end
  end

  context "with actual_states argument" do
    let(:filter_arguments) { { actual_states: [states_module::RUNNING] } }

    it "returns only workspaces matching the specified actual_states" do
      expect(collection_proxy).to contain_exactly(workspace_a)
    end
  end

  context "with multiple arguments" do
    let(:filter_arguments) do
      {
        ids: [workspace_a.id, workspace_b.id, other_users_workspace.id],
        user_ids: [workspace_owner_user.id, other_user.id],
        project_ids: [project_a.id, project_b.id, project_c.id],
        agent_ids: [agent_a.id, agent_b.id],
        actual_states: [
          states_module::RUNNING,
          states_module::TERMINATED
        ]
      }
    end

    it "handles multiple arguments and still returns all workspaces which match all filter arguments",
      :unlimited_max_formatted_output_length do
      expect(collection_proxy).to contain_exactly(workspace_a, workspace_b, other_users_workspace)
    end
  end

  context "with extra empty filter arguments" do
    let(:filter_arguments) do
      {
        ids: [workspace_a.id],
        user_ids: [],
        project_ids: [],
        agent_ids: [],
        actual_states: []
      }
    end

    it "still uses existing filter arguments" do
      expect(collection_proxy).to contain_exactly(workspace_a)
    end
  end

  describe "ordering" do
    context "with user_ids argument" do
      let(:filter_arguments) { { user_ids: [workspace_owner_user.id] } }

      it "returns users' workspaces sorted by last updated time (most recent first)" do
        expected_collection_proxy = [workspace_b, workspace_a]
        expect(collection_proxy).to eq(expected_collection_proxy)
      end
    end
  end

  describe "validations" do
    context "when an invalid actual_state is provided" do
      let(:filter_arguments) { { actual_states: ["InvalidActualState1"] } }

      it "raises an ArgumentError" do
        expect { collection_proxy }
          .to raise_error(ArgumentError, "Invalid actual state value provided: 'InvalidActualState1'")
      end
    end

    context "when no filter arguments are provided" do
      let(:filter_arguments) { {} }

      before do
        allow(::RemoteDevelopment::FilterArgumentValidator).to receive(
          :validate_at_least_one_filter_argument_provided!
        ).and_raise(ArgumentError.new("At least one filter argument must be provided"))
      end

      it "raises an ArgumentError" do
        expect { collection_proxy }.to raise_error(ArgumentError, "At least one filter argument must be provided")
      end
    end

    context "when an invalid filter argument type is provided" do
      let(:expected_exception_message) do
        "'ids' must be an Array of 'Integer', " \
          "'user_ids' must be an Array of 'Integer', " \
          "'project_ids' must be an Array of 'Integer', " \
          "'agent_ids' must be an Array of 'Integer', " \
          "'actual_states' must be an Array of 'String'"
      end

      before do
        allow(::RemoteDevelopment::FilterArgumentValidator).to receive(
          :validate_filter_argument_types!
        ).and_raise(RuntimeError.new(expected_exception_message))
      end

      context "when argument is not an array" do
        let(:filter_arguments) do
          {
            ids: 1,
            user_ids: 1,
            project_ids: 1,
            agent_ids: 1,
            actual_states: "a"
          }
        end

        it "raises an RuntimeError", :unlimited_max_formatted_output_length do
          expect { collection_proxy.to_a }.to raise_error(RuntimeError, expected_exception_message)
        end
      end

      context "when array content is wrong type" do
        let(:filter_arguments) do
          {
            ids: %w[a b],
            user_ids: %w[a b],
            project_ids: %w[a b],
            agent_ids: %w[a b],
            actual_states: [1, 2]
          }
        end

        it "raises an RuntimeError", :unlimited_max_formatted_output_length do
          expect { collection_proxy.to_a }.to raise_error(RuntimeError, expected_exception_message)
        end
      end
    end

    context "when current_user does not have access_workspaces_feature ability (anonymous user)" do
      let(:filter_arguments) { { actual_states: ["doesn't matter, not used or checked"] } }

      before do
        allow(current_user).to receive(:can?).with(:access_workspaces_feature).and_return(false)
      end

      it "returns none" do
        expect(collection_proxy).to be_blank
      end
    end
  end
end
