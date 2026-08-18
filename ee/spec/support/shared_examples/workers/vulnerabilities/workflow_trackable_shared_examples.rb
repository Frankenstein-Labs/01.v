# frozen_string_literal: true

RSpec.shared_examples 'a workflow trackable worker' do |next_item_id:|
  let(:execution_id) { SecureRandom.uuid }

  let(:execution) do
    Vulnerabilities::BulkDuoWorkflow::ExecutionState.new(
      execution_id: execution_id,
      project_id: finding.project_id,
      workflow: described_class::WORKFLOW_DEFINITION
    )
  end

  before do
    allow(execution).to receive_messages(
      status: :running,
      batch_size: 100,
      cancel_requested?: false,
      pending_ids_by_stage: {},
      mark_completed!: [nil, []],
      mark_failed!: [nil, []],
      mark_cancelled!: [nil, []]
    )

    allow(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
      .to receive(:fetch).with(
        execution_id: execution_id,
        project_id: finding.project_id,
        workflow: described_class::WORKFLOW_DEFINITION
      )
                         .and_return(execution)
  end

  describe 'workflow tracking' do
    context 'without execution_id' do
      let(:execution_id) { nil }

      it 'does not fetch execution state' do
        expect(Vulnerabilities::BulkDuoWorkflow::ExecutionState).not_to receive(:fetch)

        perform
      end
    end

    context 'when bulk_vulnerabilities_duo_workflow_api is disabled' do
      before do
        stub_feature_flags(bulk_vulnerabilities_duo_workflow_api: false)
      end

      it 'does not fetch execution state' do
        expect(Vulnerabilities::BulkDuoWorkflow::ExecutionState).not_to receive(:fetch)

        perform
      end

      it 'does not mark the finding as completed' do
        perform

        expect(execution).not_to have_received(:mark_completed!)
      end
    end

    context 'with execution_id' do
      it 'fetches the execution state' do
        expect(Vulnerabilities::BulkDuoWorkflow::ExecutionState)
          .to receive(:fetch).with(
            execution_id: execution_id,
            project_id: finding.project_id,
            workflow: described_class::WORKFLOW_DEFINITION
          )
          .and_return(execution)

        perform
      end

      it 'marks the finding as completed' do
        perform

        expect(execution).to have_received(:mark_completed!).with([finding.uuid])
      end

      context 'when execution is cancelled' do
        before do
          allow(execution).to receive(:cancel_requested?).and_return(true)
        end

        it 'marks the finding as cancelled' do
          perform

          expect(execution).to have_received(:mark_cancelled!).with([finding.uuid])
        end

        it 'cancels pending findings' do
          allow(execution).to receive(:pending_ids_by_stage).and_return({ 0 => [1, 2] })

          perform

          expect(execution).to have_received(:mark_cancelled!).with([1, 2], stage_order: 0)
        end

        it 'does not mark the finding as completed' do
          perform

          expect(execution).not_to have_received(:mark_completed!)
        end
      end

      context 'when a next batch is returned' do
        before do
          allow(execution).to receive(:mark_completed!)
                                .and_return([
                                  Vulnerabilities::BulkDuoWorkflow::VulnerabilityScripts::RESULTS[:batch_complete],
                                  [finding.uuid]
                                ])
        end

        it 'enqueues the next item' do
          expect(described_class).to receive(:perform_async).with(
            instance_exec(&next_item_id),
            execution.execution_id
          )

          perform
        end
      end
    end
  end

  describe 'retry exhaustion' do
    it 'delegates retry exhaustion to the handler' do
      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:handle_retry_exhaustion).with({ 'args' => [item_id, execution.execution_id] })
      end

      described_class.sidekiq_retries_exhausted_block.call(
        { 'args' => [item_id, execution.execution_id] },
        StandardError.new
      )
    end

    context 'when bulk_vulnerabilities_duo_workflow_api is disabled' do
      before do
        stub_feature_flags(bulk_vulnerabilities_duo_workflow_api: false)
      end

      it 'does not mark the finding as failed' do
        described_class.sidekiq_retries_exhausted_block.call(
          { 'args' => [item_id, execution.execution_id] },
          StandardError.new
        )

        expect(execution).not_to have_received(:mark_failed!)
      end
    end

    it 'marks the finding as failed' do
      described_class.sidekiq_retries_exhausted_block.call(
        { 'args' => [item_id, execution.execution_id] },
        StandardError.new
      )

      expect(execution).to have_received(:mark_failed!).with([finding.uuid])
    end

    context 'when a next batch is returned' do
      before do
        allow(execution).to receive(:mark_failed!)
                              .and_return([
                                Vulnerabilities::BulkDuoWorkflow::VulnerabilityScripts::RESULTS[:batch_complete],
                                [finding.uuid]
                              ])
      end

      it 'enqueues the next item' do
        expect(described_class).to receive(:perform_async).with(
          instance_exec(&next_item_id),
          execution.execution_id
        )

        described_class.sidekiq_retries_exhausted_block.call(
          { 'args' => [item_id, execution.execution_id] },
          StandardError.new
        )
      end
    end
  end
end
