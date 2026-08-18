# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectsComplianceEnqueueWorker,
  feature_category: :compliance_management do
  let(:worker) { described_class.new }
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: group) }
  let_it_be(:project2) { create(:project, namespace: group) }
  let_it_be(:project3) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  before do
    create(:compliance_framework_project_setting, project: project1, compliance_management_framework: framework)
    create(:compliance_framework_project_setting, project: project2, compliance_management_framework: framework)
  end

  describe '#perform' do
    subject(:perform) { worker.perform(framework.id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [framework.id] }
    end

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    context 'when given valid parameters' do
      it 'enqueues only the projects applied to the framework' do
        expect(ComplianceManagement::ProjectComplianceEvaluatorWorker)
          .to receive(:schedule_compliance_evaluation)
          .with(framework.id, match_array([project1.id, project2.id])).once

        perform
      end
    end

    context 'when given invalid parameters' do
      shared_examples 'returns early without processing' do
        it 'does nothing' do
          expect(ComplianceManagement::ProjectComplianceEvaluatorWorker).not_to receive(:schedule_compliance_evaluation)

          subject
        end
      end

      context 'when framework_id is nil' do
        subject(:perform) { worker.perform(nil) }

        it_behaves_like 'returns early without processing'
      end

      context 'when framework_id is non existent' do
        subject(:perform) { worker.perform(non_existing_record_id) }

        it_behaves_like 'returns early without processing'
      end
    end
  end
end
