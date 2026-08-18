# frozen_string_literal: true

module GitlabSubscriptions
  class DiscoverDuoProComponent < BaseDiscoverComponent
    extend ::Gitlab::Utils::Override

    private

    override :trial_type
    def trial_type
      'duo_pro'
    end

    override :trial_active?
    def trial_active?
      GitlabSubscriptions::Trials::DuoPro.active_add_on_purchase_for_namespace?(namespace)
    end

    override :discover_card_collection
    def discover_card_collection
      [
        {
          header: s_('DuoProDiscover|Privacy-first AI'),
          body: s_(
            "DuoProDiscover|Maintain control over the data that's sent to an external large language model (LLM) " \
              "service. Your organization's proprietary data or code are never used to train external AI models."
          )
        },
        {
          header: s_('DuoProDiscover|Boost team collaboration'),
          body: s_(
            "DuoProDiscover|Streamline communication, facilitate knowledge sharing, and improve project management."
          )
        },
        {
          header: s_('DuoProDiscover|Improve developer experience'),
          body: s_(
            "DuoProDiscover|A single platform integrates the best AI model for each use case across the entire " \
              "development workflow."
          )
        },
        {
          header: s_('DuoProDiscover|Transparent AI'),
          body: safe_format(
            s_(
              "DuoProDiscover|The GitLab %{link_start}AI Transparency Center%{link_end} details how we uphold " \
                "ethics and transparency in our AI-native features."
            ),
            tag_pair(
              link_to(
                '', 'https://about.gitlab.com/ai-transparency-center/',
                data: {
                  testid: 'ai-transparency-link',
                  track_action: documentation_link_track_action,
                  track_label: 'ai_transparency_center_feature'
                },
                class: 'gl-contents',
                target: '_blank',
                rel: 'noopener noreferrer'
              ),
              :link_start,
              :link_end
            )
          )
        }
      ]
    end

    override :core_section_one_card_collection
    def core_section_one_card_collection
      [
        {
          header: s_('DuoProDiscover|Boost productivity with smart code assistance'),
          body: s_(
            "DuoProDiscover|Write secure code faster and save time with Code Suggestions in more than 20 " \
              "languages, available in your favorite IDE."
          ),
          footer: render_footer_link(
            link_text: s_('DuoProDiscover|GitLab Duo Code Suggestions'),
            link_path: 'https://www.youtube.com/watch?v=ds7SG1wgcVM',
            track_label: 'code_assistance_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoProDiscover|Real-time guidance'),
          body: s_(
            "DuoProDiscover|Use Chat to get up to speed on the status of projects, and quickly learn about " \
              "GitLab, directly in your IDE or web interface."
          ),
          footer: render_footer_link(
            link_text: s_('DuoProDiscover|GitLab Duo Chat'),
            link_path: 'https://www.youtube.com/watch?v=ZQBAuf-CTAY&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED',
            track_label: 'real_time_guidance_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoProDiscover|Automate mundane tasks'),
          body: s_("DuoProDiscover|Catch bugs early in the workflow by generating tests for the selected content."),
          footer: render_footer_link(
            link_text: s_('DuoProDiscover|GitLab Duo Test generation'),
            link_path: 'https://www.youtube.com/watch?v=zWhwuixUkYU&list=PLFGfElNsQthYDx0A_FaNNfUm9NHsK6zED',
            track_label: 'automate_tasks_feature',
            track_action: documentation_link_track_action
          )
        },
        {
          header: s_('DuoProDiscover|Modernize code faster'),
          body: s_(
            "DuoProDiscover|Streamline the refactoring process with AI-native recommendations to optimize " \
              "code structure and improve readability."
          ),
          footer: render_footer_link(
            link_text: s_('DuoProDiscover|Refactor code into modern languages with AI-native GitLab Duo'),
            link_path: 'https://about.gitlab.com/blog/2024/08/26/refactor-code-into-modern-languages-with-ai-powered-gitlab-duo/',
            track_label: 'modernize_code_feature',
            track_action: documentation_link_track_action
          )
        }
      ]
    end

    override :glm_content
    def glm_content
      'discover-duo-pro'
    end

    override :text_page_title
    def text_page_title
      _('Discover Duo Pro')
    end

    override :hero_logo
    def hero_logo
      'duo_pro/logo.svg'
    end

    override :hero_logo_dark
    def hero_logo_dark
      'duo_pro/logo-dark.svg'
    end

    override :hero_header_text
    def hero_header_text
      s_(
        'DuoProDiscover|Ship software faster and more securely with AI integrated into your entire DevSecOps lifecycle.'
      )
    end

    override :buy_now_link
    def buy_now_link
      ::Gitlab::Routing.url_helpers.subscription_portal_add_saas_duo_pro_seats_url(namespace.id)
    end

    override :buy_now_ref_source
    def buy_now_ref_source
      'group_discover_duo_pro_page'
    end

    override :cta_button_text
    def cta_button_text
      _('Buy now')
    end

    override :hero_video
    def hero_video
      'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479'
    end

    override :hero_thumbnail
    def hero_thumbnail
      'duo_pro/video-thumbnail.png'
    end

    override :why_section_header_text
    def why_section_header_text
      s_('DuoProDiscover|Why GitLab Duo Pro?')
    end

    override :core_feature_one_header_text
    def core_feature_one_header_text
      s_('DuoProDiscover|Boost productivity with smart code assistance')
    end
  end
end
