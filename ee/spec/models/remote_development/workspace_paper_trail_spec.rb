# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
# noinspection RubyResolve -- RubyMine not detecting workspace.workspaces_agent_config_version association
RSpec.describe RemoteDevelopment::Workspace, "paper_trail behavior", feature_category: :workspaces do
  ##########
  # NOTE: This spec tests the behavior of the paper_trail library and its usage by the Workspace#workspaces_agent_config
  #       method. These are kept separate from the rest of the Workspace model specs in `workspace_spec.rb`, because
  #       it makes many modifications to the fixture instances involved in the spec, which can cause them to be
  #       brittle or interact in unexpected ways with the other fixtures/examples in the main `workspace_spec.rb`
  #       There's also some still-unexplained behavior with equality checks - see the to-do comments below
  #       related to https://gitlab.com/gitlab-org/gitlab/-/issues/494671.

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:agent) { create(:ee_cluster_agent) }
  let_it_be_with_reload(:agent_config) { create(:workspaces_agent_config, agent: agent) }

  subject(:workspace) do
    create(:workspace, user: user, agent: agent, workspaces_agent_config_version: agent_config.versions.size)
  end

  describe "#workspaces_agent_config" do
    context "with new unpersisted workspace record" do
      context "when workspaces_agent_config_version is nil" do
        it "returns latest workspaces_agent_config" do
          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end
    end

    context "with persisted workspace record" do
      context "when workspaces_agent_config_version is 0" do
        before do
          agent_config.versions.destroy_all # rubocop:disable Cop/DestroyAll -- can't use delete_all, it causes a validation err
          workspace.save!
        end

        it "returns actual workspaces_agent_config record" do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(0)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end

      context "when workspaces_agent_config_version is 1" do
        before do
          workspace.save!
        end

        it "returns actual workspaces_agent_config record" do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(1)

          # fixture sanity check, ensure a single "create" event version exists
          versions = agent_config.reload.versions
          expect(versions.size).to eq(1)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end

      context "when workspaces_agent_config_version is greater than 1" do
        before do
          agent_config.touch
          workspace.save!
        end

        it "returns reified version of workspaces_agent_config" do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(2)

          # fixture sanity check, ensure a second version ("update" event type) exists
          versions = agent_config.versions.reload
          expect(versions.size).to eq(2)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end

        context "when workspaces_agent_config_versions gets a new version" do
          it "still returns same workspaces_agent_config which matches the old version" do
            # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
            expect(workspace.workspaces_agent_config_version).to eq(2)

            agent_config.touch

            # fixture sanity check, ensure a third version ("update" event type) exists
            versions = agent_config.versions.reload
            expect(versions.size).to eq(3)

            agent_config_on_workspace = workspace.reload.workspaces_agent_config
            expect(agent_config_on_workspace.updated_at).to eq(versions[2].reify.updated_at)
            expect(agent_config_on_workspace).to eql(versions[2].reify)

            # should also not match any of the other previous versions
            expect(agent_config_on_workspace.updated_at).not_to eq(versions[1].reify.updated_at)
            expect(agent_config_on_workspace).not_to eq(versions[0].reify) # versions[0].reify will be nil

            # TODO: Why don't these pass? Something seems off with equality checks or maybe fixtures...
            #       We should understand this, or else it could cause unexpected behavior or bugs.
            #       https://gitlab.com/gitlab-org/gitlab/-/issues/494671
            # expect(agent_config_on_workspace).not_to eql(versions[1].reify)
          end

          it "does not return the latest workspaces_agent_config" do
            agent_config.touch

            agent_config_on_workspace = workspace.reload.workspaces_agent_config
            expect(agent_config_on_workspace.updated_at).not_to eq(agent_config.updated_at)

            # TODO: Why don't these pass? Something seems off with equality checks or maybe fixtures...
            #       We should understand this, or else it could cause unexpected behavior or bugs.
            #       https://gitlab.com/gitlab-org/gitlab/-/issues/494671
            # expect(agent_config == agent_config_on_workspace).to eq(false)
            # expect(agent_config_on_workspace == agent_config).to eq(false)
            # expect(agent_config_on_workspace).to_not eq(agent_config)
            # expect(agent_config_on_workspace.eql?(agent_config)).to eq(false)
            # expect(agent_config_on_workspace).to_not eql(agent_config)
          end
        end
      end
    end
  end
end
