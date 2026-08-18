# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::WorkflowTriggerable, feature_category: :vulnerability_management do
  let(:worker_class) do
    Class.new do
      def self.name
        'TestWorkflowWorker'
      end

      include ApplicationWorker
      include Vulnerabilities::WorkflowTriggerable
    end
  end

  let(:worker) { worker_class.new }

  describe '#resolve_workflow_user' do
    let_it_be(:project) { create(:project) }
    let_it_be(:author) { create(:user) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project, author: author) }

    context 'when author has duo_workflow permission' do
      before do
        allow(Ability).to receive(:allowed?).with(author, :duo_workflow, project).and_return(true)
      end

      it 'returns the author' do
        result = worker.send(:resolve_workflow_user, vulnerability, project)

        expect(result).to eq(author)
      end

      it 'does not log any info message' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        worker.send(:resolve_workflow_user, vulnerability, project)
      end
    end

    context 'when author does not have duo_workflow permission' do
      before do
        allow(Ability).to receive(:allowed?).with(author, :duo_workflow, project).and_return(false)
      end

      it 'returns nil' do
        result = worker.send(:resolve_workflow_user, vulnerability, project)

        expect(result).to be_nil
      end

      it 'logs an info message' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Vulnerability author does not have duo_workflow permission',
          vulnerability_id: vulnerability.id,
          project_id: project.id,
          author_id: author.id
        )

        worker.send(:resolve_workflow_user, vulnerability, project)
      end
    end

    context 'when author is nil' do
      before do
        allow(vulnerability).to receive(:author).and_return(nil)
      end

      it 'returns nil' do
        result = worker.send(:resolve_workflow_user, vulnerability, project)

        expect(result).to be_nil
      end

      it 'logs an info message with nil author_id' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Vulnerability author does not have duo_workflow permission',
          vulnerability_id: vulnerability.id,
          project_id: project.id,
          author_id: nil
        )

        worker.send(:resolve_workflow_user, vulnerability, project)
      end
    end
  end

  describe '#log_no_eligible_user' do
    let_it_be(:project) { create(:project) }
    let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

    it 'logs an error with vulnerability and project context' do
      expect(Gitlab::AppLogger).to receive(:error).with(
        message: 'No eligible user found for vulnerability workflow, ' \
          'author lacks duo_workflow permission',
        vulnerability_id: vulnerability.id,
        project_id: project.id
      )

      worker.send(:log_no_eligible_user, vulnerability, project)
    end
  end
end
