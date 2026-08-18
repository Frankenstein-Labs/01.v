# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Update::Main, "Integration", feature_category: :workspaces do
  include_context "with constant modules"

  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:workspace) do
    create(:workspace, user: user, desired_state: states_module::RUNNING)
  end

  let(:new_desired_state) { states_module::STOPPED }
  let(:params) { { desired_state: new_desired_state } }
  let(:context) { { workspace: workspace, user: user, params: params } }

  subject(:response) do
    described_class.main(context)
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'when workspace update is successful' do
    it 'updates the workspace and returns success' do
      expect { response }.to change { workspace.reload.desired_state }.to(new_desired_state)

      expect(response).to eq({
        status: :success,
        payload: { workspace: workspace }
      })
    end
  end

  context 'when workspace update fails' do
    let(:new_desired_state) { 'InvalidDesiredState' }

    it 'does not update the workspace and returns error' do
      expect { response }.not_to change { workspace.reload }

      expect(response).to eq({
        status: :error,
        message: "Workspace update failed: Desired state is not included in the list",
        reason: :bad_request
      })
    end
  end
end
