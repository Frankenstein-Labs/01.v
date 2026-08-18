# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Refresh::ApprovalWorker, feature_category: :code_review_workflow do
  describe '#perform' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let(:worker) { described_class.new }
    let(:oldrev) { 'old_sha' }
    let(:newrev) { 'new_sha' }
    let(:ref) { 'refs/heads/master' }

    subject(:execute) { worker.perform(project.id, user.id, oldrev, newrev, ref) }

    before_all do
      project.add_developer(user)
    end

    context 'when all records exist' do
      it 'calls the approval service' do
        expect_next_instance_of(MergeRequests::Refresh::ApprovalService,
          project: project, current_user: user) do |instance|
          expect(instance)
            .to receive(:execute)
            .with(oldrev, newrev, ref)
        end

        execute
      end
    end

    shared_examples 'when a record does not exist' do
      it 'does not call the approval service' do
        expect(MergeRequests::Refresh::ApprovalService).not_to receive(:new)

        expect { execute }.not_to raise_exception
      end
    end

    context 'when the project does not exist' do
      subject(:execute) { worker.perform(-1, user.id, oldrev, newrev, ref) }

      it_behaves_like 'when a record does not exist'
    end

    context 'when the user does not exist' do
      subject(:execute) { worker.perform(project.id, -1, oldrev, newrev, ref) }

      it_behaves_like 'when a record does not exist'
    end

    describe 'error handling in service' do
      context 'when approval service raises an error' do
        before do
          allow_next_instance_of(MergeRequests::Refresh::ApprovalService) do |service|
            allow(service).to receive(:execute).and_raise(StandardError, 'Approval processing failed')
          end
        end

        it 'allows the error to propagate' do
          expect { execute }.to raise_error(StandardError, 'Approval processing failed')
        end
      end
    end
  end
end
