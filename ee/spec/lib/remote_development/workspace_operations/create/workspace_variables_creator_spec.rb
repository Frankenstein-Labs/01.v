# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator, feature_category: :workspaces do
  include ResultMatchers

  include_context "with remote development shared fixtures"

  # noinspection RubyArgCount -- https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  # The desired state of the workspace is set to running so that a workspace token gets associated to it.
  let_it_be_with_refind(:workspace) do
    create(
      :workspace, :without_workspace_variables,
      user: user, personal_access_token: personal_access_token, desired_state: states_module::RUNNING
    )
  end

  let(:vscode_extension_marketplace) do
    {
      service_url: "service_url",
      item_url: "item_url",
      resource_url_template: "resource_url_template"
    }
  end

  let(:gitlab_kas_external_url) { "ws://kas.example.com/-/external/namespace/path" }
  let(:variable_type) { RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE }

  let(:user_provided_variables) do
    [
      { key: "key1", value: "value 1", type: variable_type },
      { key: "key2", value: "value 2", type: variable_type }
    ]
  end

  let(:context) do
    {
      workspace: workspace,
      personal_access_token: personal_access_token,
      user: user,
      vscode_extension_marketplace: vscode_extension_marketplace,
      params: {
        variables: user_provided_variables
      },
      settings: {
        gitlab_kas_external_url: gitlab_kas_external_url
      }
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord method
  end

  it "has fixture sanity check" do
    # We must ensure the workspace fixture, which simulates a workspace in the ROP create chain in the process of being
    # created, does not contain any pre-existing associated workspace_variable records
    expect(workspace.workspace_variables.count).to eq(0)
  end

  context "when workspace variables create is successful" do
    let(:valid_variable_type) { RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE }
    let(:variable_type) { valid_variable_type }
    let(:expected_number_of_records_saved) { 23 }

    it "creates the workspace variable records and returns ok result containing original context" do
      expect { result }.to change { workspace.workspace_variables.count }.by(expected_number_of_records_saved)

      expect(workspace.workspace_variables.find_by_key("key1").value).to eq("value 1")
      expect(workspace.workspace_variables.find_by_key("key2").value).to eq("value 2")

      expect(result).to be_ok_result(context)
    end

    context "when workspace url helper's common_workspace_host_suffix? returns true" do
      let(:workspace_host_suffix) { "workspaces.host.suffix" }
      let(:agentw_token_file_name) do
        RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::AGENTW_TOKEN_FILE_NAME
      end

      before do
        stub_config(workspaces: { host: workspace_host_suffix })

        allow(RemoteDevelopment::WorkspaceOperations::WorkspaceUrlHelper)
          .to receive(:common_workspace_host_suffix?)
            .and_return(true)
      end

      it "creates the workspace variable records and returns ok result containing original context" do
        expect { result }.to change { workspace.workspace_variables.count }.by(expected_number_of_records_saved)

        expect(workspace.workspace_variables.find_by_key(agentw_token_file_name).value).to match(/glwt-.*/)

        expect(result).to be_ok_result(context)
      end
    end
  end

  context "when workspace create fails" do
    let(:invalid_variable_type) { 9999999 }
    let(:variable_type) { invalid_variable_type }
    let(:expected_number_of_records_saved) { 21 }

    it "does not create the invalid workspace variable records and returns an error result with model errors" do
      # NOTE: Any valid records will be saved if they are first in the array before the invalid record, but that's OK,
      #       because if we return an err_result, the entire transaction will be rolled back at a higher level.
      expect { result }.to change { workspace.workspace_variables.count }.by(expected_number_of_records_saved)

      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key1")).to be_nil
      expect(RemoteDevelopment::WorkspaceVariable.find_by_key("key2")).to be_nil

      expect(result).to be_err_result do |message|
        expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceVariablesModelCreateFailed)
        message.content => { errors: ActiveModel::Errors => errors }
        expect(errors.full_messages).to match([/variable type/i])
      end
    end
  end
end
