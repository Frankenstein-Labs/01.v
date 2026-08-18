# frozen_string_literal: true

module EE
  module MergeRequests
    module CreateService
      include ::MergeRequests::ApprovalRulesAttributeMapping
      extend ::Gitlab::Utils::Override

      override :set_default_attributes!
      def set_default_attributes!
        super

        return map_and_replace_approval_rules_attributes_to_v2 if create_v2_approval_rules?

        return if params[:approval_rules_attributes].present?

        # Pick only regular or any_approver to match frontend behavior:
        # See https://gitlab.com/gitlab-org/gitlab/blob/ea40bc69a9309e0c8691588a920383394ebc649c/ee/app/assets/javascripts/approvals/mappers.js#L80-88
        # See issue: https://gitlab.com/gitlab-org/gitlab/-/issues/408380
        approval_rules_attrs = project.approval_rules.regular_or_any_approver.map(&:to_nested_attributes)
        params[:approval_rules_attributes] = approval_rules_attrs if approval_rules_attrs.present?
      end

      override :after_create
      def after_create(issuable)
        issuable.approval_state.temporarily_unapprove!

        if issuable.reviewer_auto_assignment_enabled?
          ::MergeRequests::ReviewerAssignment::PendingInitialAssignment.mark(issuable)
        end

        issuable.run_after_commit do
          ::MergeRequests::SyncCodeOwnerApprovalRulesWorker.perform_async(
            issuable.id,
            'expire_unapproved_key' => true
          )
        end

        super

        ::MergeRequests::SyncReportApproverApprovalRules.new(issuable, current_user).execute

        ::MergeRequests::UpdateBlocksService
          .new(issuable, current_user, blocking_merge_requests_params)
          .execute

        stream_audit_event(issuable)

        link_creating_duo_workflow(issuable)
      end

      def before_create(merge_request)
        super

        merge_request.run_after_commit do
          merge_request.approval_state.temporarily_unapprove!
        end

        assign_duo_as_reviewer_automatically(merge_request) unless merge_request.draft?
      end

      private

      # The header is client-supplied, so authorize the current user against the workflow
      def link_creating_duo_workflow(merge_request)
        workflow_id = ::Gitlab::ApplicationContext.current_context_attribute(:duo_workflow_id)
        return unless workflow_id

        workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(workflow_id)
        return unless workflow
        return unless ::Ability.allowed?(current_user, :update_duo_workflow, workflow)

        ::Ai::DuoWorkflows::LinkArtifactService.new(
          workflow: workflow,
          artifact: merge_request,
          link_type: :created
        ).execute
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e, duo_workflow_id: workflow_id)
      end

      def stream_audit_event(merge_request)
        audit_context = {
          name: 'merge_request_create',
          stream_only: true,
          author: current_user,
          scope: merge_request.project,
          target: merge_request,
          message: 'Added merge request'
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      override :filter_approval_params
      def filter_approval_params(merge_request, current_user, params)
        return super unless create_v2_approval_rules?

        ::MergeRequests::V2ApprovalRules::ParamsFilteringService.new(merge_request, current_user, params).execute
      end

      def create_v2_approval_rules?
        ::Feature.enabled?(:v2_approval_rules, project)
      end
    end
  end
end
