# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflowRegistry, feature_category: :vulnerability_management do
  describe '.fetch' do
    let(:expected_workflows) do
      {
        Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION => {
          worker: Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker
        },
        Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION => {
          worker: Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker
        },
        Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION => {
          worker: Vulnerabilities::TriggerResolutionWorkflowWorker
        }
      }
    end

    it 'contains all supported workflows' do
      expect(described_class::WORKFLOWS.keys).to match_array(expected_workflows.keys)
    end

    it 'returns the expected worker for every workflow' do
      expected_workflows.each do |workflow, expected|
        expect(described_class.fetch(workflow)[:worker]).to eq(expected[:worker])
      end
    end

    describe 'resolve_ids' do
      shared_examples 'resolves vulnerability ids' do |workflow|
        let_it_be(:vulnerability) { create(:vulnerability) }
        let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability) }

        it 'returns vulnerability ids for finding uuids' do
          resolver = described_class.fetch(workflow)[:resolve_ids]

          expect(resolver.call([finding.uuid])).to eq([vulnerability.id])
        end
      end

      include_examples 'resolves vulnerability ids',
        Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION

      include_examples 'resolves vulnerability ids',
        Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION

      context 'for the resolution workflow' do
        let_it_be(:finding) { create(:vulnerabilities_finding) }

        let_it_be(:flag) do
          create(:vulnerabilities_flag, :false_positive, finding: finding)
        end

        it 'returns false positive flag ids for finding uuids' do
          resolver = described_class.fetch(
            Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION
          )[:resolve_ids]

          expect(resolver.call([finding.uuid])).to eq([flag.id])
        end
      end
    end

    context 'when the workflow is unknown' do
      it 'raises an error' do
        expect { described_class.fetch('unknown') }
          .to raise_error(ArgumentError, 'Unknown workflow: unknown')
      end
    end
  end
end
