# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsValidator, feature_category: :workspaces do
  include ResultMatchers

  let(:update_type) { "partial" }
  let(:workspace_error_details) { nil }
  let(:workspace_agent_infos) do
    [{
      termination_progress: "Terminated",
      error_details: workspace_error_details
    }]
  end

  let(:original_params) do
    {
      workspace_agent_infos: workspace_agent_infos,
      update_type: update_type
    }
  end

  let(:context) { { original_params: original_params } }

  subject(:result) do
    described_class.validate(context)
  end

  context 'when original_params are valid' do
    shared_examples 'success result' do
      it 'return an ok Result containing the original context which was passed' do
        expect(result).to eq(Gitlab::Fp::Result.ok(context))
      end
    end

    context 'when update_type is "full"' do
      let(:update_type) { "full" }
      let(:workspace_agent_infos) { [] }

      it_behaves_like 'success result'
    end

    context 'when error_details nil' do
      let(:workspace_error_details) { nil }

      it_behaves_like 'success result'
    end

    context 'with error_details present' do
      shared_examples "with valid error_type" do |err_type|
        let(:workspace_error_details) do
          {
            error_type: err_type,
            error_message: "something has gone wrong"
          }
        end

        it_behaves_like 'success result'
      end

      include_examples "with valid error_type", "applier"
      include_examples "with valid error_type", "kubernetes"
    end
  end

  context 'when original_params are invalid' do
    shared_examples 'err result' do |expected_error_details:|
      it 'returns an err Result containing error details nil original_params and an error' do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceReconcileParamsValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq(expected_error_details)
        end
      end
    end

    context 'when missing required entries' do
      let(:original_params) { {} }

      it_behaves_like 'err result', expected_error_details:
        %(root is missing required keys: update_type, workspace_agent_infos)
    end

    context 'for workspace_agent_infos' do
      context 'when not an array' do
        let(:workspace_agent_infos) { "NOT AN ARRAY" }

        it_behaves_like 'err result', expected_error_details:
          %(property '/workspace_agent_infos' is not of type: array)
      end
    end

    context 'for update_type' do
      context 'when not "partial" or "full"' do
        let(:update_type) { "INVALID UPDATE TYPE" }

        it_behaves_like 'err result', expected_error_details:
          %(property '/update_type' is not one of: ["partial", "full"])
      end
    end

    context 'for error_details' do
      context 'when error_type is missing' do
        let(:workspace_error_details) do
          {
            error_message: "something has gone wrong"
          }
        end

        it_behaves_like 'err result', expected_error_details:
          "property '/workspace_agent_infos/0/error_details' is missing required keys: error_type"
      end

      context 'when error_type has an invalid context' do
        let(:workspace_error_details) do
          {
            error_type: "INVALID ERROR TYPE",
            error_message: "something has gone wrong"
          }
        end

        it_behaves_like 'err result', expected_error_details:
          %(property '/workspace_agent_infos/0/error_details/error_type' is not one of: ["applier", "kubernetes"])
      end
    end

    context 'for termination_progress' do
      context 'when termination_progress is invalid' do
        let(:workspace_agent_infos) do
          [{
            termination_progress: "invalidValue"
          }]
        end

        it_behaves_like 'err result', expected_error_details:
          %(property '/workspace_agent_infos/0/termination_progress' is not one of: ["Terminating", "Terminated"])
      end
    end
  end
end
