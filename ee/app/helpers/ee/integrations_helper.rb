# frozen_string_literal: true

module EE
  module IntegrationsHelper
    extend ::Gitlab::Utils::Override

    override :project_jira_issues_integration?
    def project_jira_issues_integration?
      @project.jira_issues_integration_available? && @project.jira_integration&.issues_enabled
    end

    override :integration_form_data
    def integration_form_data(integration, project: nil, group: nil)
      form_data = super

      if integration.is_a?(Integrations::Jira)
        form_data.merge!(
          show_jira_issues_integration: (project || group)&.jira_issues_integration_available?.to_s,
          show_jira_vulnerabilities_integration: integration.jira_vulnerabilities_integration_available?.to_s,
          enable_jira_issues: integration.issues_enabled.to_s,
          enable_jira_vulnerabilities: integration.jira_vulnerabilities_integration_enabled?.to_s,
          project_key: integration.project_key,
          project_keys: integration.project_keys_as_string,
          vulnerabilities_issuetype: integration.vulnerabilities_issuetype,
          customize_jira_issue_enabled: integration.customize_jira_issue_enabled.to_s
        )
      end

      if integration.is_a?(::Integrations::GoogleCloudPlatform::ArtifactRegistry)
        form_data.merge!(
          artifact_registry_path: project_google_cloud_artifact_registry_index_path(project),
          operating: integration.operating?.to_s
        )

        if project.google_cloud_platform_workload_identity_federation_integration&.operating?
          form_data.merge!(
            workload_identity_federation_project_number: project.google_cloud_platform_workload_identity_federation_integration.workload_identity_federation_project_number,
            workload_identity_pool_id: project.google_cloud_platform_workload_identity_federation_integration.workload_identity_pool_id
          )
        else
          form_data.merge!(
            editable: 'false',
            workload_identity_federation_path: edit_project_settings_integration_path(
              project, :google_cloud_platform_workload_identity_federation
            )
          )
        end
      end

      if integration.is_a?(::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation)
        form_data[:wlif_issuer] = ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.wlif_issuer_url(group || project)
        form_data[:jwt_claims] = ::Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.jwt_claim_mapping_script_value
      end

      if integration.is_a?(::Integrations::AmazonQ)
        form_data[:amazon_q] = amazon_q_data(integration)
      end

      form_data
    end

    def jira_issues_show_data
      {
        issues_show_path: project_integrations_jira_issue_path(@project, params[:id], format: :json),
        issues_list_path: project_integrations_jira_issues_path(@project)
      }
    end

    override :integration_event_title
    def integration_event_title(event)
      return _('Vulnerability') if event == 'vulnerability'

      super
    end

    override :default_integration_event_description
    def default_integration_event_description(event)
      return s_("ProjectService|Trigger event when a new, unique vulnerability is recorded. (Note: This feature requires an Ultimate plan.)") if event == 'vulnerability'

      super
    end

    def external_issue_breadcrumb_title(issue_reference)
      strip_tags(issue_reference)
    end

    def zentao_issue_breadcrumb_link(issue)
      external_issue_breadcrumb_link('logos/zentao.svg', issue[:id], issue[:web_url], target: '_blank')
    end

    def zentao_issues_show_data
      {
        issues_show_path: project_integrations_zentao_issue_path(@project, params[:id], format: :json),
        issues_list_path: project_integrations_zentao_issues_path(@project)
      }
    end

    def amazon_q_data(integration)
      result = ::Ai::AmazonQ::IdentityProviderPayloadFactory.new.execute

      identity_provider =
        case result
        in { ok: payload }
          payload
        in { err: err }
          flash[:alert] = [
            s_('AmazonQ|Something went wrong retrieving the identity provider payload.'),
            err[:message]
          ].join(' ').squish

          {}
        end

      {
        submit_url: admin_ai_amazon_q_settings_path,
        disconnect_url: disconnect_admin_ai_amazon_q_settings_path,
        ready: ::Ai::Setting.for_organization_read_only(::Current.organization).amazon_q_ready.to_s,
        role_arn: ::Ai::Setting.for_organization_read_only(::Current.organization).amazon_q_role_arn,
        availability: ::Gitlab::CurrentSettings.duo_availability,
        auto_review_enabled: integration.auto_review_enabled.to_s
      }.merge(identity_provider)
    end

    def integrations_allow_list_data
      integrations = Integration.available_integration_names(include_blocked_by_settings: true).map do |integration|
        model = Integration.integration_name_to_model(integration)

        { title: model.title, name: model.to_param }
      end

      {
        integrations: integrations.to_json,
        allow_all_integrations: @application_setting.integrations['allow_all_integrations'].to_s,
        allowed_integrations: @application_setting.integrations['allowed_integrations'].to_json
      }
    end

    override :jira_specific_form_data
    def jira_specific_form_data(integration)
      return {} unless integration.is_a?(Integrations::Jira)

      super.merge!({
        jira_check_enabled: integration.jira_check_enabled.to_s,
        jira_exists_check_enabled: integration.jira_exists_check_enabled.to_s,
        jira_assignee_check_enabled: integration.jira_assignee_check_enabled.to_s,
        jira_status_check_enabled: integration.jira_status_check_enabled.to_s,
        jira_allowed_statuses_as_string: integration.jira_allowed_statuses_as_string
      })
    end

    private

    # Use this method when dealing with issue data from external services
    # (like Jira or ZenTao).
    # Returns a sanitized `ActiveSupport::SafeBuffer` link.
    def external_issue_breadcrumb_link(img, text, href, options = {})
      icon = image_tag image_path(img), width: 15, height: 15, class: 'gl-mr-2'
      link = sanitize(
        link_to(
          strip_tags(text),
          strip_tags(href),
          options.merge(
            rel: 'noopener noreferrer',
            class: 'gl-flex gl-items-center gl-whitespace-nowrap'
          )
        ),
        tags: %w[a img],
        attributes: %w[target href src loading rel class width height]
      )

      [icon, link].join.html_safe
    end
  end
end
