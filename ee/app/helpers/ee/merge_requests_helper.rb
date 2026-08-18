# frozen_string_literal: true

module EE
  module MergeRequestsHelper
    extend ::Gitlab::Utils::Override

    override :summarize_new_merge_request_disabled_reason
    def summarize_new_merge_request_disabled_reason(merge_request)
      source_head_sha = merge_request.source_branch_sha
      target_head_sha = merge_request.target_branch_sha

      if source_head_sha.nil?
        s_('NewMergeRequest|Source branch not available')
      elsif target_head_sha.nil?
        s_('NewMergeRequest|Target branch not available')
      elsif !merge_request.has_diffs?
        s_('NewMergeRequest|No changes between source and target branches')
      else
        super
      end
    end

    override :diffs_tab_pane_data
    def diffs_tab_pane_data(project, merge_request, params)
      data = {
        endpoint_codequality: (codequality_mr_diff_reports_project_merge_request_path(project, merge_request, 'json') if project.licensed_feature_available?(:inline_codequality) && merge_request.has_codequality_mr_diff_report?),
        sast_report_available: merge_request.has_sast_reports?.to_s
      }

      data[:codequality_report_available] = merge_request.has_codequality_reports?.to_s if project.licensed_feature_available?(:inline_codequality)

      super.merge(data)
    end

    override :mr_compare_form_data
    def mr_compare_form_data(user, merge_request)
      target_branch_finder_path = if can?(user, :read_target_branch_rule, merge_request.project)
                                    project_target_branch_rules_path(merge_request.project)
                                  end

      super.merge({ target_branch_finder_path: target_branch_finder_path })
    end

    override :review_bar_data
    def review_bar_data(merge_request, user)
      super.merge({ can_summarize: Ability.allowed?(user, :access_summarize_review, merge_request).to_s })
    end

    override :identity_verification_alert_data
    def identity_verification_alert_data(merge_request)
      {
        identity_verification_required: show_iv_alert_for_mr?(merge_request).to_s,
        identity_verification_path: identity_verification_path
      }
    end

    override :sticky_header_data
    def sticky_header_data(project, merge_request)
      data = super

      if project.licensed_feature_available?(:security_dashboard)
        data[:tabs].insert(data[:tabs].size - 1, ['reports', _('Reports'), reports_project_merge_request_path(project, merge_request), 3])
      end

      data
    end

    override :project_merge_requests_list_data
    def project_merge_requests_list_data(project, current_user)
      super.merge({
        merge_trains_path: merge_trains_available?(project) && can?(current_user, :read_merge_train, project) ? project_merge_trains_path(project) : nil,
        has_scoped_labels_feature: project.licensed_feature_available?(:scoped_labels).to_s
      })
    end

    override :group_merge_requests_list_data
    def group_merge_requests_list_data(group, current_user)
      super.merge({
        has_scoped_labels_feature: group.licensed_feature_available?(:scoped_labels).to_s
      })
    end

    def can_resolve_with_ai?(merge_request)
      merge_request.can_resolve_with_ai?(current_user)
    end

    private

    def show_iv_alert_for_mr?(merge_request)
      return false unless current_user
      return false unless current_user == merge_request.author
      return false unless merge_request.project

      !::Users::IdentityVerification::AuthorizeCi.new(user: current_user, project: merge_request.project).user_can_run_jobs?
    end
  end
end
