# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator, feature_category: :workspaces do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let(:random_string) { 'abcdef' }
  let(:devfile_path) { '.devfile.yaml' }
  let(:devfile_yaml) { example_devfile_yaml }
  let(:processed_devfile) { example_flattened_devfile }
  let(:desired_state) { states_module::RUNNING }

  let(:params) do
    {
      agent: agent,
      user: user,
      project: project,
      desired_state: desired_state,
      project_ref: 'main',
      devfile_path: devfile_path
    }
  end

  let(:context) do
    namespace_prefix = create_constants_module::NAMESPACE_PREFIX
    {
      params: params,
      user: user,
      devfile_yaml: devfile_yaml,
      processed_devfile: processed_devfile,
      personal_access_token: personal_access_token,
      workspace_name: "workspace-#{agent.id}-#{user.id}-#{random_string}",
      workspace_namespace: "#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}",
      volume_mounts: {
        data_volume: {
          name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME,
          path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
        }
      }
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord method
  end

  context 'when workspace create is successful' do
    it 'creates the workspace and returns ok result containing successful message with created workspace' do
      expect { result }.to change { project.workspaces.count }

      expect(result).to be_ok_result do |message|
        message => { workspace: RemoteDevelopment::Workspace => workspace }
        expect(workspace).to eq(project.workspaces.last)
      end
    end

    it 'creates the workspace with the right url components' do
      expect(result).to be_ok_result do |message|
        message => { workspace: RemoteDevelopment::Workspace => workspace }
        expected_url = "https://#{create_constants_module::WORKSPACE_EDITOR_PORT}-#{workspace.name}." \
          "#{agent.unversioned_latest_workspaces_agent_config.dns_zone}/" \
          "?folder=%2Fprojects%2F#{project.path}"
        expect(workspace.url).to eq(expected_url)
      end
    end
  end

  context 'when workspace create fails' do
    let(:desired_state) { 'InvalidDesiredState' }

    it 'does not create the workspace and returns an error result containing a failed message with model errors' do
      expect { result }.not_to change { project.workspaces.count }

      expect(result).to be_err_result do |message|
        expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceModelCreateFailed)
        message.content => { errors: ActiveModel::Errors => errors }
        expect(errors.full_messages).to match([/desired state/i])
      end
    end
  end
end
