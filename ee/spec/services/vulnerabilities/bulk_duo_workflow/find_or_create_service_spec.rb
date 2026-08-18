# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::FindOrCreateService,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:workflow) { :sast_fp_detection }
  let(:metadata) { { fingerprint: 'abc123' } }

  let(:stages) do
    [
      { name: 'critical', order: 0 },
      { name: 'high', order: 1 }
    ]
  end

  subject(:response) do
    described_class.new(
      project: project,
      workflow: workflow,
      stages: stages,
      metadata: metadata,
      current_user: current_user
    ).execute
  end

  before do
    allow(Ability).to receive(:allowed?)
                        .with(current_user, :execute_vulnerability_duo_workflow, project).and_return(true)
  end

  describe '#execute' do
    it 'creates an execution', :aggregate_failures do
      expect(response).to be_success

      execution = response.payload[:execution]

      expect(response.message).to eq('Execution created')
      expect(response.payload[:created]).to be(true)
      expect(execution).to be_present
      expect(execution.status).to eq(:created)
      expect(execution.workflow_metadata).to eq(metadata.stringify_keys)
    end

    it 'returns the existing execution', :aggregate_failures do
      initial_execution = response.payload[:execution]

      second = described_class.new(
        project: project,
        workflow: workflow,
        stages: stages,
        current_user: current_user
      ).execute

      expect(second).to be_success
      expect(second.message).to eq('Execution already exists')
      expect(second.payload[:created]).to be(false)
      expect(second.payload[:execution].execution_id).to eq(initial_execution.execution_id)
    end
  end
end
