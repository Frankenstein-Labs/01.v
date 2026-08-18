# frozen_string_literal: true

module EE
  module Gitlab
    module EventStore
      module Subscriptions
        module MergeRequestsSubscriptions
          def register
            super

            store.subscribe ::MergeRequests::StreamApprovalAuditEventWorker, to: ::MergeRequests::ApprovedEvent
            store.subscribe ::MergeRequests::ApprovalMetricsEventWorker, to: ::MergeRequests::ApprovedEvent
            store.subscribe ::MergeRequests::CreateApprovalsResetNoteWorker, to: ::MergeRequests::ApprovalsResetEvent
            store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
              to: ::MergeRequests::ExternalStatusCheckPassedEvent
            store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::UnblockedStateEvent
            store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
              to: ::MergeRequests::OverrideRequestedChangesStateEvent
            store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::ApprovedEvent
            store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
              to: ::MergeRequests::ViolationsUpdatedEvent
            store.subscribe ::MergeRequests::RemoveUserApprovalRulesWorker,
              to: ::ProjectAuthorizations::AuthorizationsRemovedEvent
            store.subscribe ::MergeRequests::ProcessMergeAuditEventWorker, to: ::MergeRequests::MergedEvent
          end
        end
      end
    end
  end
end
