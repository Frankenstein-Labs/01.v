# frozen_string_literal: true

module Projects
  module LearnGitlabHelper
    IMAGE_PATH_CODE = "learn_gitlab/section_code.svg"
    IMAGE_PATH_PLAN = "learn_gitlab/section_plan.svg"
    IMAGE_PATH_DEPLOY = "learn_gitlab/section_deploy.svg"
    IMAGE_PATH_WORKSPACE = "learn_gitlab/section_workspace.svg"
    GITLAB_COM = 'gitlab.com'
    ONBOARDING_START_TRIAL = 'onboarding-start-trial'
    ONBOARDING_REQUIRE_MR_APPROVALS = 'onboarding-require-merge-approvals'
    ONBOARDING_CODE_OWNERS = 'onboarding-code-owners'

    def learn_gitlab_data(project)
      {
        actions: onboarding_actions_data(project).to_json,
        sections: onboarding_sections_data.to_json,
        project: onboarding_project_data(project).to_json,
        learn_gitlab_end_path: end_tutorial_project_learn_gitlab_path(project)
      }
    end

    private

    def onboarding_actions_data(project)
      data = action_urls(project).transform_values do |url|
        {
          url: url,
          enabled: true
        }
      end

      unless can_start_trial?(project)
        data[:trial_started][:enabled] = false
        data[:trial_started][:message] =
          s_('LearnGitlab|Contact your administrator to start a free Ultimate trial.')
      end

      data
    end

    def can_assign_duo_seats?(project)
      root = project.root_ancestor

      GitlabSubscriptions::Duo.any_active_add_on_purchase_for_namespace?(root) &&
        can?(current_user, :read_usage_quotas, root)
    end

    def can_start_trial?(project)
      root = project.root_ancestor
      root.has_free_or_no_subscription? && can?(current_user, :admin_namespace, root)
    end

    def onboarding_sections_data
      [
        {
          code: {
            svg: image_path(IMAGE_PATH_CODE)
          }
        },
        {
          workspace: {
            svg: image_path(IMAGE_PATH_WORKSPACE)
          },
          plan: {
            svg: image_path(IMAGE_PATH_PLAN)
          },
          deploy: {
            svg: image_path(IMAGE_PATH_DEPLOY)
          }
        }
      ]
    end

    def onboarding_project_data(project)
      {
        name: project.name
      }
    end

    def action_urls(project)
      urls = {
        pipeline_created: project_pipelines_path(project),
        issue_created: project_work_items_path(project),
        created: project_path(project),
        merge_request_created: project_merge_requests_path(project),
        user_added: '#',
        code_added: CGI.unescape(ide_project_edit_path(project.full_path)),
        **deploy_section_action_urls(project)
      }

      trial_items = {
        trial_started: project_project_members_path(project),
        required_mr_approvals_enabled: help_page_path('ci/testing/code_coverage/coverage_reporting.md',
          anchor: 'add-a-coverage-check-approval-rule'),
        code_owners_enabled: help_page_path('user/project/codeowners/_index.md', anchor: 'set-up-code-owners')
      }

      if can_start_trial?(project)
        namespace_id = project.root_ancestor.id
        trial_items = {
          trial_started: new_trial_path_with_glm(namespace_id: namespace_id, content: ONBOARDING_START_TRIAL),
          required_mr_approvals_enabled: new_trial_path_with_glm(
            namespace_id: namespace_id, content: ONBOARDING_REQUIRE_MR_APPROVALS
          ),
          code_owners_enabled: new_trial_path_with_glm(namespace_id: namespace_id, content: ONBOARDING_CODE_OWNERS)
        }
      end

      if can_assign_duo_seats?(project)
        urls[:duo_seat_assigned] = group_settings_gitlab_duo_seat_utilization_index_path(project.root_ancestor)
      end

      urls.merge(trial_items)
    end

    def new_trial_path_with_glm(namespace_id:, content:, source: GITLAB_COM)
      new_trial_path({ namespace_id: namespace_id, glm_source: source, glm_content: content })
    end

    def deploy_section_action_urls(project)
      {
        license_scanning_run: help_page_path('user/compliance/license_scanning_of_cyclonedx_files/_index.md'),
        secure_dependency_scanning_run: project_security_configuration_path(project, anchor: 'dependency-scanning'),
        secure_dast_run: project_security_configuration_path(project, anchor: 'dast')
      }
    end
  end
end
