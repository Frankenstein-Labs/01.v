# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::RemoveUserApprovalRulesWorker, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:project_id) { project.id }
  let(:user_ids) { [user.id] }
  let(:data) { { project_id: project_id, user_ids: user_ids } }
  let(:authorizations_event) { ProjectAuthorizations::AuthorizationsRemovedEvent.new(data: data) }

  it_behaves_like 'subscribes to event' do
    let(:event) { authorizations_event }

    it 'calls ApprovalRules::UserRulesDestroyService' do
      expect_next_instance_of(
        ApprovalRules::UserRulesDestroyService,
        project: project
      ) do |service|
        expect(service).to receive(:execute).with([user.id])
      end

      consume_event(subscriber: described_class, event: authorizations_event)
    end

    context 'when the project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'logs and does not call ApprovalRules::UserRulesDestroyService' do
        expect(Sidekiq.logger).to receive(:info).with(
          hash_including('message' => 'Project not found.', 'project_id' => project_id)
        )
        expect(ApprovalRules::UserRulesDestroyService).not_to receive(:new)

        expect { consume_event(subscriber: described_class, event: authorizations_event) }.not_to raise_exception
      end
    end

    context 'when the user_ids are empty' do
      let(:user_ids) { [] }

      it 'does not call ApprovalRules::UserRulesDestroyService' do
        expect(ApprovalRules::UserRulesDestroyService).not_to receive(:new)

        expect { consume_event(subscriber: described_class, event: authorizations_event) }.not_to raise_exception
      end
    end
  end
end
