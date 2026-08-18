# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::DuoWorkflowHelpers, feature_category: :duo_agent_platform do
  let(:helper) do
    Class.new do
      include API::Helpers::DuoWorkflowHelpers
      include Gitlab::Utils::StrongMemoize

      attr_accessor :params

      def current_user
        nil
      end
    end.new
  end

  describe '#link_vulnerability_to_user_triggered_workflow' do
    let_it_be(:project) { create(:project) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
    let_it_be(:workflow) do
      create(:duo_workflows_workflow, project: project,
        workflow_definition: 'resolve_sast_vulnerability/v1')
    end

    before do
      helper.params = { goal: vulnerability.id.to_s }
    end

    it 'creates a Vulnerabilities::TriggeredWorkflow row linking the vulnerability and workflow' do
      expect { helper.link_vulnerability_to_user_triggered_workflow(workflow) }
        .to change { ::Vulnerabilities::TriggeredWorkflow.count }.by(1)

      record = ::Vulnerabilities::TriggeredWorkflow.last
      expect(record.workflow_id).to eq(workflow.id)
      expect(record.vulnerability_occurrence_id).to eq(vulnerability.finding.id)
      expect(record.workflow_name).to eq('resolve_sast_vulnerability')
    end

    context 'when the workflow_definition is not one of the vulnerability definitions' do
      let(:other_workflow) { create(:duo_workflows_workflow, workflow_definition: 'software_developer') }

      it 'is a no-op' do
        expect { helper.link_vulnerability_to_user_triggered_workflow(other_workflow) }
          .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
      end
    end

    context 'when the workflow is nil' do
      it 'returns without creating a row' do
        expect { helper.link_vulnerability_to_user_triggered_workflow(nil) }
          .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
      end
    end

    context 'when the goal does not resolve to a vulnerability' do
      before do
        helper.params = { goal: '999999' }
      end

      it 'is a no-op' do
        expect { helper.link_vulnerability_to_user_triggered_workflow(workflow) }
          .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
      end
    end

    context 'when the resulting row is invalid' do
      it 'rescues the error, tracks it, and returns nil' do
        invalid_workflow = create(:duo_workflows_workflow,
          workflow_definition: 'resolve_sast_vulnerability/v1',
          project: create(:project))

        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(ActiveRecord::RecordInvalid),
          hash_including(workflow_id: invalid_workflow.id)
        )

        expect(helper.link_vulnerability_to_user_triggered_workflow(invalid_workflow)).to be_nil
      end
    end
  end

  describe '#inject_secret_fp_detection_context' do
    let(:user) { build_stubbed(:user) }
    let(:finding) { instance_double(Vulnerabilities::Finding, token_value: 'glpat-secret-token') }
    let(:vulnerability) { instance_double(Vulnerability, finding: finding) }

    before do
      allow(helper).to receive_messages(current_user: user, vulnerability_from_goal: vulnerability)
      allow(Ability).to receive(:allowed?).with(user, :read_vulnerability, vulnerability).and_return(true)
    end

    it 'appends a secret_detection_context envelope with the secret value and version metadata' do
      result = helper.inject_secret_fp_detection_context([])

      envelope = result.find { |ctx| ctx[:category] == 'secret_detection_context' }
      expect(envelope[:content]).to eq({ secret_value: 'glpat-secret-token' }.to_json)

      # metadata is a raw Hash (not a JSON string); the duo-cli executor encodes it before sending to DWS
      expect(envelope["metadata"]).to eq({ "version" => "1.0.0" })
    end

    context 'when the user cannot read the vulnerability' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_vulnerability, vulnerability).and_return(false)
      end

      it 'returns the context unchanged' do
        expect(helper.inject_secret_fp_detection_context([])).to eq([])
      end
    end
  end

  describe '#push_feature_flags' do
    let_it_be(:user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(Gitlab::AiGateway).to receive(:push_feature_flag)
    end

    it 'pushes duo_chat_clarification_question_tool feature flag' do
      helper.push_feature_flags

      expect(Gitlab::AiGateway).to have_received(:push_feature_flag)
        .with(:duo_chat_clarification_question_tool, user)
    end

    it 'pushes dependency_bump_run_command feature flag' do
      helper.push_feature_flags

      expect(Gitlab::AiGateway).to have_received(:push_feature_flag)
        .with(:dependency_bump_run_command, user)
    end

    it 'pushes dw_read_blobs_api for the root namespace so the gateway can gate the blob read path' do
      root_namespace = create(:group)

      helper.push_feature_flags(root_namespace)

      expect(Gitlab::AiGateway).to have_received(:push_feature_flag)
        .with(:dw_read_blobs_api, root_namespace)
    end

    it 'pushes the duo_workflow_read_incremental_checkpoints kill switch for the root namespace' do
      root_namespace = create(:group)

      helper.push_feature_flags(root_namespace)

      expect(Gitlab::AiGateway).to have_received(:push_feature_flag)
        .with(:duo_workflow_read_incremental_checkpoints, root_namespace)
    end
  end
end
