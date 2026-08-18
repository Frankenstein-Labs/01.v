# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesToBeReturnedUpdater, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }

  let_it_be_with_reload(:workspace1) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace1",
      agent: agent,
      user: user,
      force_include_all_resources: false
    )
  end

  let_it_be_with_reload(:workspace2) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace2",
      agent: agent,
      user: user,
      force_include_all_resources: false
    )
  end

  let_it_be_with_reload(:workspace3) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace3",
      agent: agent,
      user: user,
      force_include_all_resources: true
    )
  end

  let_it_be(:workspace4) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace4",
      agent: agent,
      user: user,
      force_include_all_resources: true
    )
  end

  let(:workspaces_to_be_returned) { [workspace1, workspace2, workspace3] }

  let(:context) do
    {
      agent: agent,
      workspaces_to_be_returned: workspaces_to_be_returned
    }
  end

  subject(:returned_value) do
    described_class.update(context) # rubocop:disable Rails/SaveBang -- This is not an ActiveRecord method
  end

  before do
    workspace1.update_attribute(:responded_to_agent_at, 2.hours.ago)
    workspace2.update_attribute(:responded_to_agent_at, 2.hours.ago)
    workspace3.update_attribute(:responded_to_agent_at, 2.hours.ago)
    agent.reload
  end

  context "with fixture sanity checks" do
    it "has the expected fixtures" do
      expect(workspace1.responded_to_agent_at).to be < 1.hour.ago
      expect(workspace2.responded_to_agent_at).to be < 1.hour.ago
    end
  end

  context "for update_type FULL" do
    it "updates all workspaces", :unlimited_max_formatted_output_length do
      returned_value
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(workspace1.reload.responded_to_agent_at).to be > 1.minute.ago
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(workspace2.reload.responded_to_agent_at).to be > 1.minute.ago
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(workspace3.reload.responded_to_agent_at).to be > 1.minute.ago
    end

    it "preserves existing context entries" do
      returned_value
      expect(returned_value).to eq(context.merge(workspaces_to_be_returned: [workspace1.reload, workspace2.reload,
        workspace3.reload]))
    end

    it 'resets force_include_all_resources to false for workspaces with true' do
      expect { returned_value }.to change { workspace3.reload.force_include_all_resources }.from(true).to(false)
    end

    it 'does not change force_include_all_resources for workspaces with false' do
      expect { returned_value }.not_to change {
        [
          workspace1.reload.force_include_all_resources,
          workspace2.reload.force_include_all_resources
        ]
      }
    end

    it 'does not include workspaces which are not passed in workspaces_to_be_returned' do
      expect(returned_value[:workspaces_to_be_returned]).not_to include(workspace4)
    end
  end
end
