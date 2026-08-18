# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CleanupMergeRequestViolationsWorker, '#perform', feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) do
    create(:merge_request, :merged, source_branch: 'feature-branch', target_branch: project.default_branch)
  end

  let_it_be_with_reload(:merge_request_violation) do
    create(:scan_result_policy_violation, :running, merge_request: merge_request)
  end

  let_it_be(:unrelated_merge_request_violation) { create(:scan_result_policy_violation) }
  let(:feature_licensed) { true }

  let(:merge_request_id) { merge_request.id }
  let(:merge_request_merged_event) { ::MergeRequests::MergedEvent.new(data: { merge_request_id: merge_request_id }) }
  let(:merge_request_closed_event) { ::MergeRequests::ClosedEvent.new(data: { merge_request_id: merge_request_id }) }
  let(:event) { merge_request_merged_event }

  subject(:perform) { consume_event(subscriber: described_class, event: event) }

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
  end

  describe 'subscriptions' do
    it_behaves_like 'subscribes to event' do
      let(:event) { merge_request_merged_event }

      it 'receives the event' do
        expect(described_class).to receive(:perform_async).with('MergeRequests::MergedEvent',
          merge_request_merged_event.data.deep_stringify_keys)
        ::Gitlab::EventStore.publish(event)
      end
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { merge_request_closed_event }

      it 'receives the event' do
        expect(described_class).to receive(:perform_async).with('MergeRequests::ClosedEvent',
          merge_request_closed_event.data.deep_stringify_keys)
        ::Gitlab::EventStore.publish(event)
      end
    end
  end

  shared_examples_for 'deletes approval policy violations' do
    it 'deletes approval policy violations' do
      expect { perform }.to change { Security::ScanResultPolicyViolation.count }.from(2).to(1)

      expect(merge_request.scan_result_policy_violations).to be_empty
    end
  end

  shared_examples_for 'does not delete approval policy violations' do
    it 'does not delete approval policy violations' do
      expect { perform }.not_to change { Security::ScanResultPolicyViolation.count }
    end
  end

  shared_examples_for 'not logging running violations' do
    it 'does not log running violations' do
      expect(Gitlab::AppJsonLogger).not_to receive(:info)

      perform
    end
  end

  shared_examples_for 'not recording audit event for violations' do
    it 'does not record merged with policy violations audit event' do
      expect(MergeRequests::MergedWithPolicyViolationsAuditEventService).not_to receive(:new)

      perform
    end
  end

  context 'with existing merge request' do
    context 'when event is MergedEvent' do
      let(:event) { merge_request_merged_event }

      it_behaves_like 'an idempotent worker'
      it_behaves_like 'deletes approval policy violations'

      it 'logs running violations' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(a_hash_including(
          workflow: 'approval_policy_evaluation',
          message: 'Running scan result policy violations after merge',
          merge_request_id: merge_request.id,
          violation_ids: [merge_request_violation.id]
        ))

        perform
      end

      it 'records merged with policy violations audit event' do
        allow_next_instance_of(::MergeRequests::MergedWithPolicyViolationsAuditEventService) do |audit_event_service|
          expect(audit_event_service).to receive(:execute)
        end

        perform
      end

      it 'preserves security policy dismissals' do
        policy_dismissal = create(:policy_dismissal, merge_request: merge_request)

        expect { perform }.to change { policy_dismissal.reload.status }.from('open').to('preserved')
      end

      context 'when there are multiple policy dismissals with different statuses' do
        let_it_be(:open_dismissal_1) { create(:policy_dismissal, merge_request: merge_request) }
        let_it_be(:open_dismissal_2) { create(:policy_dismissal, merge_request: merge_request) }
        let_it_be(:preserved_dismissal) { create(:policy_dismissal, merge_request: merge_request, status: 1) }

        it 'only preserves open policy dismissals' do
          expect { perform }.to change { open_dismissal_1.reload.status }.from('open').to('preserved')
                            .and change { open_dismissal_2.reload.status }.from('open').to('preserved')
                            .and not_change { preserved_dismissal.reload.status }
        end
      end

      context 'when policy dismissal is no longer applicable' do
        let_it_be(:project) { merge_request.project }
        let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
        let_it_be(:security_policy) do
          create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
        end

        let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
        let_it_be(:violation) do
          create(:scan_result_policy_violation, :new_scan_finding,
            project: project,
            merge_request: merge_request,
            approval_policy_rule: approval_policy_rule,
            uuids: %w[uuid-1 uuid-2])
        end

        let_it_be(:non_applicable_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            security_policy: security_policy,
            security_findings_uuids: ['uuid-1']) # Missing uuid-2
        end

        it 'destroys non-applicable policy dismissals during preservation' do
          expect { perform }.to change { Security::PolicyDismissal.exists?(non_applicable_dismissal.id) }
            .from(true).to(false)
        end
      end

      context 'when there is no merge_request scan result policy violations' do
        before do
          merge_request_violation.update!(merge_request_id: unrelated_merge_request_violation.merge_request_id)
        end

        it_behaves_like 'not logging running violations'
        it_behaves_like 'not recording audit event for violations'
      end

      context 'when there are no running violations' do
        before do
          merge_request_violation.update!(status: :failed)
        end

        it_behaves_like 'not logging running violations'
      end
    end

    context 'when event is ClosedEvent' do
      let(:event) { merge_request_closed_event }

      it_behaves_like 'an idempotent worker'
      it_behaves_like 'deletes approval policy violations'

      it_behaves_like 'not logging running violations'
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it_behaves_like 'does not delete approval policy violations'
    end
  end

  context 'with non-existing merge request' do
    let(:merge_request_id) { non_existing_record_id }

    it_behaves_like 'does not delete approval policy violations'
  end
end
