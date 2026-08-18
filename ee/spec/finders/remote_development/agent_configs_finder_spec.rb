# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::AgentConfigsFinder, feature_category: :workspaces do
  let_it_be(:current_user) { create(:user) }

  let_it_be(:cluster_admin_user) { create(:user) }
  let_it_be(:agent_a) do
    create(:ee_cluster_agent, created_by_user: cluster_admin_user)
  end

  let_it_be(:agent_b) do
    create(:ee_cluster_agent, created_by_user: cluster_admin_user)
  end

  let_it_be(:agent_config_a) do
    create(:workspaces_agent_config, agent: agent_a)
  end

  let_it_be(:agent_config_b) do
    create(:workspaces_agent_config, agent: agent_b)
  end

  subject(:collection_proxy) do
    described_class.execute(current_user: current_user, **filter_arguments)
  end

  before do
    stub_licensed_features(remote_development: true)
    allow(::RemoteDevelopment::FilterArgumentValidator).to receive_messages(validate_filter_argument_types!: true,
      validate_at_least_one_filter_argument_provided!: true)
  end

  context "with ids argument" do
    let(:filter_arguments) { { ids: [agent_config_a.id] } }

    it "returns only agent configs matching the specified IDs" do
      expect(collection_proxy).to contain_exactly(agent_config_a)
    end
  end

  context "with cluster_agent_ids argument" do
    let(:filter_arguments) { { cluster_agent_ids: [agent_a.id] } }

    it "returns only agent configs matching the specified agent IDs" do
      expect(collection_proxy).to contain_exactly(agent_config_a)
    end
  end

  context "with multiple arguments" do
    let(:filter_arguments) do
      {
        ids: [agent_config_a.id],
        cluster_agent_ids: [agent_a.id, agent_b.id]
      }
    end

    it "handles multiple arguments and still returns all agent configs which match all filter arguments" do
      expect(collection_proxy).to contain_exactly(agent_config_a)
    end
  end

  context "with extra empty filter arguments" do
    let(:filter_arguments) do
      {
        ids: [agent_config_a.id],
        cluster_agent_ids: []
      }
    end

    it "still uses existing filter arguments" do
      expect(collection_proxy).to contain_exactly(agent_config_a)
    end
  end

  describe "validations" do
    context "when no filter arguments are provided" do
      before do
        allow(::RemoteDevelopment::FilterArgumentValidator).to receive(
          :validate_at_least_one_filter_argument_provided!
        ).and_raise(ArgumentError.new("At least one filter argument must be provided"))
      end

      let(:filter_arguments) { {} }

      it "raises an ArgumentError" do
        expect { collection_proxy }.to raise_error(ArgumentError, "At least one filter argument must be provided")
      end
    end

    context "when an invalid filter argument type is provided" do
      let(:expected_exception_message) do
        "'ids' must be an Array of 'Integer', " \
          "'cluster_agent_ids' must be an Array of 'Integer'"
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
            cluster_agent_ids: 1
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
            cluster_agent_ids: %w[a b]
          }
        end

        it "raises an RuntimeError", :unlimited_max_formatted_output_length do
          expect { collection_proxy.to_a }.to raise_error(RuntimeError, expected_exception_message)
        end
      end
    end
  end

  describe "no workspaces feature" do
    before do
      stub_licensed_features(remote_development: false)
    end

    let(:filter_arguments) { { ids: [agent_config_a.id] } }

    it "returns no agent config" do
      expect(collection_proxy).to eq([])
    end
  end
end
