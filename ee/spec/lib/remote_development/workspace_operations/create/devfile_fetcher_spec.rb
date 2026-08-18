# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::DevfileFetcher, feature_category: :workspaces do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  subject(:result) do
    described_class.fetch(context)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, :repository) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let(:random_string) { 'abcdef' }
  let(:project_ref) { 'main' }
  let(:params) do
    {
      agent: agent,
      user: user,
      project: project,
      desired_state: states_module::RUNNING,
      project_ref: project_ref,
      devfile_path: devfile_path
    }
  end

  let(:default_devfile_yaml) { example_default_devfile_yaml }

  let(:context) do
    {
      params: params,
      settings: {
        default_devfile_yaml: default_devfile_yaml
      }
    }
  end

  context 'when params are valid' do
    let(:devfile) { yaml_safe_load_symbolized(devfile_yaml) }

    context 'when devfile_path is points to an existing file' do
      let(:devfile_path) { '.devfile.yaml' }
      let(:devfile_fixture_name) { 'example.devfile.yaml.erb' }
      let(:devfile_yaml) { read_devfile_yaml(devfile_fixture_name) }

      before do
        allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
      end

      it 'returns an ok Result containing the original params and the devfile_yaml' do
        expect(result).to eq(
          Gitlab::Fp::Result.ok({
            params: params,
            devfile_yaml: devfile_yaml,
            settings: {
              default_devfile_yaml: default_devfile_yaml
            }
          })
        )
      end
    end

    context 'when devfile_path is nil' do
      let(:devfile_path) { nil }
      let(:devfile_yaml) { default_devfile_yaml }

      it 'returns an ok Result containing the original params and the default devfile_yaml_string' do
        expect(result).to eq(
          Gitlab::Fp::Result.ok({
            params: params,
            devfile_yaml: devfile_yaml,
            settings: {
              default_devfile_yaml: default_devfile_yaml
            }
          })
        )
      end
    end
  end

  context 'when params are invalid' do
    before do
      allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
    end

    context 'when agent has no associated config' do
      let(:devfile_path) { '.devfile.yaml' }

      let_it_be(:agent) { create(:cluster_agent) }

      it 'returns an err Result containing error details' do
        # sanity check on fixture
        expect(agent.unversioned_latest_workspaces_agent_config).to be_nil

        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateParamsValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq("No WorkspacesAgentConfig found for agent '#{agent.name}'")
        end
      end
    end

    context 'when devfile_path does not exist' do
      let(:devfile_path) { 'not-found.yaml' }

      before do
        allow(project.repository).to receive(:blob_at_branch).and_return(nil)
      end

      it 'returns an err Result containing error details' do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileLoadFailed)
          message.content => { details: String => error_details }
          expect(error_details)
            .to eq("Devfile path '#{devfile_path}' at ref '#{project_ref}' does not exist in the project repository")
        end
      end
    end

    context 'when devfile_path is empty string' do
      let(:devfile_path) { '' }

      before do
        allow(project.repository).to receive(:blob_at_branch).and_return(nil)
      end

      it 'returns an err Result containing error details' do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileLoadFailed)
          message.content => { details: String => error_details }
          expect(error_details)
            .to eq("Devfile path '#{devfile_path}' at ref '#{project_ref}' does not exist in the project repository")
        end
      end
    end

    context 'when devfile blob data could not be loaded' do
      let(:devfile_path) { '.devfile.yaml' }

      before do
        allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { '' }
      end

      it 'returns an err Result containing error details' do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileLoadFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq("Devfile could not be loaded from project")
        end
      end
    end
  end
end
