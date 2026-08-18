# frozen_string_literal: true

module GitlabSubscriptions
  class DiscoverDuoEnterpriseComponent < DiscoverDuoProComponent
    extend ::Gitlab::Utils::Override

    private

    override :trial_type
    def trial_type
      'duo_enterprise'
    end

    override :trial_active?
    def trial_active?
      GitlabSubscriptions::Trials::DuoEnterprise.active_add_on_purchase_for_namespace?(namespace)
    end

    override :buy_now_link
    def buy_now_link; end

    override :core_section_one_card_collection
    def core_section_one_card_collection
      [
        {
          header: s_('DuoEnterpriseDiscover|Boost productivity with smart code assistance'),
          body: s_(
            "DuoEnterpriseDiscover|Write secure code faster with AI-native suggestions in more than 20 languages, " \
              "and chat with your AI companion throughout development."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Code Suggestions'),
            link_path: 'https://www.youtube.com/watch?v=ds7SG1wgcVM',
            track_label: 'code_assistance_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Fortify your code'),
          body: s_(
            "DuoEnterpriseDiscover|AI-native vulnerability explanation and resolution features to remediate " \
              "vulnerabilities and uplevel skills."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Vulnerability explanation'),
            link_path: 'https://www.youtube.com/watch?v=MMVFvGrmMzw',
            track_label: 'vulnerability_explanation_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Advanced troubleshooting'),
          body: s_(
            "DuoEnterpriseDiscover|AI-assisted root cause analysis for CI/CD job failures, and suggested " \
              "fixes to quickly remedy broken pipelines."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Root cause analysis'),
            link_path: 'https://www.youtube.com/watch?v=Sa0UBpMqXgs',
            track_label: 'root_cause_analysis_feature',
            track_action: documentation_link_track_action
          )
        }
      ]
    end

    override :core_section_two_card_collection
    def core_section_two_card_collection
      [
        {
          header: s_('DuoEnterpriseDiscover|Summarization and templating'),
          body: s_(
            "DuoEnterpriseDiscover|Discussion, merge request, and code summaries for efficient and effective " \
              "communication."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|GitLab Duo Code review summary'),
            link_path: 'https://www.youtube.com/watch?v=Bx6Zajyuy9k',
            track_label: 'code_review_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoEnterpriseDiscover|Measure the ROI of AI'),
          body: s_(
            "DuoEnterpriseDiscover|Granular usage data, performance improvements, and productivity metrics to " \
              "evaluate the effectiveness of AI in software development."
          ),
          footer: render_footer_link(
            link_text: s_('DuoEnterpriseDiscover|AI Impact Dashboard measures the ROI of AI'),
            link_path: 'https://about.gitlab.com/blog/2024/05/15/developing-gitlab-duo-ai-impact-analytics-dashboard-measures-the-roi-of-ai/',
            track_label: 'ai_impact_analytics_dashboard_feature',
            track_action: documentation_link_track_action
          )
        }
      ]
    end

    override :glm_content
    def glm_content
      'discover-duo-enterprise'
    end

    override :text_page_title
    def text_page_title
      _('Discover Duo Enterprise')
    end

    override :why_section_header_text
    def why_section_header_text
      s_('DuoEnterpriseDiscover|Why GitLab Duo Enterprise?')
    end

    override :core_feature_one_header_text
    def core_feature_one_header_text
      s_('DuoEnterpriseDiscover|Your end-to-end AI partner')
    end

    override :core_feature_one_grid_class
    def core_feature_one_grid_class
      '@md/panel:gl-grid-cols-3'
    end

    override :core_feature_two_grid_class
    def core_feature_two_grid_class
      '@md/panel:gl-grid-cols-2'
    end
  end
end
