# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::BackgroundMigration::BackfillWorkspaceAgentkStates, feature_category: :workspaces do
  let(:organization) { table(:organizations).create!(name: "test-org", path: "default") }
  let(:processed_devfile) do
    read_fixture_file("processed_devfile.yaml")
  end

  let!(:workspace_1) do
    table(:workspaces).create!(
      user_id: user.id,
      project_id: project.id,
      cluster_agent_id: agent.id,
      desired_state_updated_at: Time.now.utc,
      actual_state_updated_at: Time.now.utc,
      responded_to_agent_at: Time.now.utc,
      name: "workspace-1",
      namespace: "workspace_1_namespace",
      desired_state: "Terminated",
      actual_state: "Terminated",
      project_ref: "devfile-ref",
      devfile_path: "devfile-path",
      devfile: devfile,
      processed_devfile: processed_devfile,
      url: "workspace-url",
      deployment_resource_version: "v1",
      personal_access_token_id: personal_access_token.id,
      workspaces_agent_config_version: agent_config_version.id
    )
  end

  let!(:workspace_2) do
    table(:workspaces).create!(
      user_id: user.id,
      project_id: project.id,
      cluster_agent_id: agent.id,
      desired_state_updated_at: Time.now.utc,
      actual_state_updated_at: Time.now.utc,
      responded_to_agent_at: Time.now.utc,
      name: "workspace-2",
      namespace: "workspace_2_namespace",
      desired_state: "Running",
      actual_state: "Running",
      project_ref: "devfile-ref",
      devfile_path: "devfile-path",
      devfile: devfile,
      processed_devfile: processed_devfile,
      url: "workspace-url",
      deployment_resource_version: "v1",
      personal_access_token_id: personal_access_token.id,
      workspaces_agent_config_version: agent_config_version.id
    )
  end

  let(:migration) do
    described_class.new(
      start_id: workspace_1.id,
      end_id: workspace_2.id,
      batch_table: :workspaces,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  let(:expected_desired_config_workspace_1) do
    json_str = read_fixture_file("desired_config.json")
    json_str.gsub!("$WORKSPACE_ID", workspace_1.id.to_s)
    json_str.gsub!("$WORKSPACE_NAMESPACE", workspace_1.namespace)
    json_str.gsub!("$WORKSPACE_NAME", workspace_1.name)
    json_str.gsub!("$REPLICA", "0")
    ::Gitlab::Json.parse(json_str)
  end

  let(:expected_desired_config_workspace_2) do
    json_str = read_fixture_file("desired_config.json")
    json_str.gsub!("$WORKSPACE_ID", workspace_2.id.to_s)
    json_str.gsub!("$WORKSPACE_NAMESPACE", workspace_2.namespace)
    json_str.gsub!("$WORKSPACE_NAME", workspace_2.name)
    json_str.gsub!("$REPLICA", "1")
    ::Gitlab::Json.parse(json_str)
  end

  let(:user) do
    table(:users).create!(
      name: "test",
      email: "test@example.com",
      projects_limit: 5,
      organization_id: organization.id
    )
  end

  let(:namespace) { table(:namespaces).create!(name: "name", path: "path", organization_id: organization.id) }
  let(:project) do
    table(:projects).create!(
      namespace_id: namespace.id,
      project_namespace_id: namespace.id,
      organization_id: organization.id
    )
  end

  let!(:personal_access_token) do
    table(:personal_access_tokens).create!(
      user_id: user.id,
      name: "token_name",
      expires_at: Time.now.utc,
      organization_id: organization.id
    )
  end

  let(:agent) do
    table(:cluster_agents).create!(
      id: 1,
      name: "Agent-1",
      project_id: project.id
    )
  end

  let!(:agent_config) do
    table(:workspaces_agent_configs).create!(
      cluster_agent_id: agent.id,
      enabled: true,
      dns_zone: "test.workspace.me",
      project_id: project.id
    )
  end

  let!(:agent_config_version) do
    table(:workspaces_agent_config_versions).create!(
      project_id: project.id,
      item_id: agent_config.id,
      item_type: "Gitlab::BackgroundMigration::RemoteDevelopment::BMWorkspacesAgentConfig",
      event: "create"
    )
  end

  let(:devfile) do
    <<~YAML
      schemaVersion: 2.2.0
      components:
        - name: tooling-container
          attributes:
            gl/inject-editor: true
          container:
            image: registry.gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/debian-bullseye-ruby-3.2-node-18.12:rubygems-3.4-git-2.33-lfs-2.9-yarn-1.22-graphicsmagick-1.3.36-gitlab-workspaces
            env:
              - name: KEY
                value: VALUE
            endpoints:
            - name: http-3000
              targetPort: 3000
    YAML
  end

  # @param [String] filename
  # @return [String]
  def read_fixture_file(filename)
    File.read(Rails.root.join("ee/spec/fixtures/remote_development/background_migration", filename).to_s)
  end

  context "when desired_config is valid" do
    it "creates a record workspace_agentk_states table for each workspace", :unlimited_max_formatted_output_length do
      expect { migration.perform }
        .to change { Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.count }
              .by(2)

      workspace_1_agentk_state_post_migration = table(:workspace_agentk_states).find_by(workspace_id: workspace_1.id)
      workspace_2_agentk_state_post_migration = table(:workspace_agentk_states).find_by(workspace_id: workspace_2.id)

      expect(workspace_1_agentk_state_post_migration.project_id).to eq(workspace_1.project_id)
      expect(workspace_2_agentk_state_post_migration.project_id).to eq(workspace_2.project_id)

      expect(workspace_1_agentk_state_post_migration.desired_config).to eq(expected_desired_config_workspace_1)
      expect(workspace_2_agentk_state_post_migration.desired_config).to eq(expected_desired_config_workspace_2)

      desired_config_1 = Gitlab::BackgroundMigration::RemoteDevelopment::WorkspaceOperations::BmDesiredConfig.new(
        desired_config_array: workspace_1_agentk_state_post_migration.desired_config)
      desired_config_2 = Gitlab::BackgroundMigration::RemoteDevelopment::WorkspaceOperations::BmDesiredConfig.new(
        desired_config_array: workspace_2_agentk_state_post_migration.desired_config)
      expect(desired_config_1).to be_valid
      expect(desired_config_2).to be_valid
    end
  end

  context "when desired_config is invalid" do
    it "creates a record in workspace_agentk_states with failed message and terminates the workspace",
      :unlimited_max_formatted_output_length do
      error = Devfile::CliError.new(
        "quantities must match the regular expression '^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$'"
      )
      allow(error).to receive(:backtrace).and_return([
        "/app/lib/some_file.rb:123:in `method_name'",
        "/app/lib/another_file.rb:456:in `another_method'"
      ])

      allow(Gitlab::BackgroundMigration::RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::BmMain)
        .to receive(:main).and_raise(error)

      expect { migration.perform }
        .to change { Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.count }
              .by(2)

      workspace_1_updated = table(:workspaces).find(workspace_1.id)
      workspace_2_updated = table(:workspaces).find(workspace_2.id)

      expect(workspace_1_updated.actual_state).to eq("Terminated")
      expect(workspace_1_updated.desired_state).to eq("Terminated")
      expect(workspace_2_updated.actual_state).to eq("Terminated")
      expect(workspace_2_updated.desired_state).to eq("Terminated")

      saved_records = Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.all
      saved_records.each do |record|
        expect(record.desired_config).to include(
          {
            "error_message" => "quantities must match the regular expression " \
              "'^([+-]?[0-9.]+)([eEinumkKMGTP]*[-+]?[0-9]*)$'",
            "message" => "Migration failed for this workspace. This workspace will be orphaned, cluster " \
              "administrators are advised to clean up the orphan workspaces.",
            "backtrace" => [
              "/app/lib/some_file.rb:123:in `method_name'",
              "/app/lib/another_file.rb:456:in `another_method'"
            ]
          }
        )
      end
    end
  end

  context "when config already exists for a workspace" do
    it "skips updating the config for that workspace", :unlimited_max_formatted_output_length do
      workspace_2_agentk_state = table(:workspace_agentk_states).create!(
        desired_config: { "some_key" => "some_value" },
        workspace_id: workspace_2.id,
        project_id: workspace_2.project_id
      )

      expect(workspace_2_agentk_state).to be_persisted

      workspace_1_agentk_state = table(:workspace_agentk_states).find_by(workspace_id: workspace_1.id)
      expect(workspace_1_agentk_state).to be_nil

      expect { migration.perform }
        .to change { Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.count }
              .by(1)

      workspace_1_agentk_state = table(:workspace_agentk_states).find_by(workspace_id: workspace_1.id)
      expect(workspace_1_agentk_state).not_to be_nil
    end
  end
end
