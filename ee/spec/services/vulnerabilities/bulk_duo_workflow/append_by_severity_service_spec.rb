# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::AppendBySeverityService,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:workflow) { :sast_fp_detection }
  let(:finding_uuids) { [critical_finding.uuid, high_finding.uuid, medium_finding.uuid] }
  let(:severities) { nil }

  let(:stages) do
    [
      { name: 'critical', order: 0 },
      { name: 'high', order: 1 },
      { name: 'medium', order: 2 }
    ]
  end

  let_it_be(:critical_finding) do
    create(:vulnerabilities_finding, project: project, severity: :critical)
  end

  let_it_be(:high_finding) do
    create(:vulnerabilities_finding, project: project, severity: :high)
  end

  let_it_be(:medium_finding) do
    create(:vulnerabilities_finding, project: project, severity: :medium)
  end

  let!(:execution) do
    Vulnerabilities::BulkDuoWorkflow::ExecutionState.create!(
      project_id: project.id,
      workflow: workflow,
      stages: stages
    )
  end

  subject(:response) do
    described_class.new(
      project: project,
      workflow: workflow,
      finding_uuids: finding_uuids,
      severities: severities,
      current_user: current_user
    ).execute
  end

  before do
    allow(Ability).to receive(:allowed?)
                        .with(current_user, :execute_vulnerability_duo_workflow, project).and_return(true)

    allow(execution).to receive(:append_to_stage!)

    allow(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
      .to receive(:current)
            .with(project_id: project.id, workflow: workflow)
            .and_return(execution)
  end

  describe '#execute' do
    context 'with an active execution' do
      it 'appends findings grouped by severity', :aggregate_failures do
        expect(response).to be_success

        expect(response.message).to eq('Items appended')
        expect(response.payload[:execution].execution_id).to eq(execution.execution_id)

        expect(execution).to have_received(:append_to_stage!)
                               .with(stage: :critical, item_ids: [critical_finding.uuid])

        expect(execution).to have_received(:append_to_stage!)
                               .with(stage: :high, item_ids: [high_finding.uuid])

        expect(execution).to have_received(:append_to_stage!)
                               .with(stage: :medium, item_ids: [medium_finding.uuid])
      end

      context 'when finding_uuids is nil' do
        let(:finding_uuids) { nil }

        it 'appends all project findings grouped by severity', :aggregate_failures do
          expect(response).to be_success

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :critical, item_ids: [critical_finding.uuid])

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :high, item_ids: [high_finding.uuid])

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :medium, item_ids: [medium_finding.uuid])
        end
      end

      context 'when severities are provided' do
        let(:severities) { %w[critical medium] }

        it 'appends only findings for the selected severities', :aggregate_failures do
          expect(response).to be_success

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :critical, item_ids: [critical_finding.uuid])

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :medium, item_ids: [medium_finding.uuid])

          expect(execution).not_to have_received(:append_to_stage!)
                                     .with(hash_including(stage: :high))
        end
      end

      context 'when severities are provided out of order' do
        let(:severities) { %w[medium critical] }

        it 'uses the execution stage order', :aggregate_failures do
          expect(response).to be_success

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :critical, item_ids: [critical_finding.uuid])

          expect(execution).to have_received(:append_to_stage!)
                                 .with(stage: :medium, item_ids: [medium_finding.uuid])

          expect(execution).not_to have_received(:append_to_stage!)
                                     .with(hash_including(stage: :high))
        end
      end

      context 'when finding_uuids contains findings from another project' do
        let_it_be(:other_project) { create(:project) }

        let_it_be(:other_finding) do
          create(:vulnerabilities_finding, project: other_project, severity: :critical)
        end

        let(:finding_uuids) { [critical_finding.uuid, other_finding.uuid] }

        it 'returns a forbidden error', :aggregate_failures do
          expect(response).to be_error
          expect(response.message).to eq('One or more findings do not belong to the project')
          expect(response.reason).to eq(:forbidden)
          expect(execution).not_to have_received(:append_to_stage!)
        end
      end
    end

    context 'when there is no active execution' do
      before do
        allow(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
          .to receive(:current)
                .with(project_id: project.id, workflow: workflow)
                .and_return(nil)
      end

      it 'returns an error', :aggregate_failures do
        expect(response).to be_error
        expect(response.message).to eq('No active execution')
        expect(response.reason).to eq(:not_found)
      end
    end
  end
end
