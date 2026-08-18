# frozen_string_literal: true

module Onboarding
  class GetStartedPresenter
    def initialize(user, project, onboarding_progress)
      @user = user
      @project = project
      @onboarding_progress = onboarding_progress
    end

    def view_model
      ::Gitlab::Json.generate(
        {
          sections: sections,
          tutorialEndPath: url_helpers.end_tutorial_project_get_started_path(project)
        }
      )
    end

    def provide
      ::Gitlab::Json.generate(
        {
          projectName: project.name,
          projectPath: project.full_path,
          sshUrl: project.ssh_url_to_repo,
          httpUrl: project.http_url_to_repo,
          defaultBranch: project.default_branch_or_main,
          canPushCode: user.can?(:push_code, project),
          canPushToBranch: user_access.can_push_to_branch?(project.default_branch_or_main),
          uploadPath: project_create_blob_path(project, project.default_branch_or_main),
          sshKeyPath: url_helpers.user_settings_ssh_keys_path
        }
      )
    end

    private

    attr_reader :user, :project, :onboarding_progress

    GLM_CONTENT = 'onboarding-start-trial'
    GLM_SOURCE = 'gitlab.com'
    private_constant :GLM_CONTENT, :GLM_SOURCE

    def sections
      [
        code_section,
        project_section,
        plan_section,
        secure_deployment_section
      ]
    end

    def code_section
      {
        title: s_('LearnGitLab|Set up your code'),
        description: nil,
        actions: [
          {
            title: s_("LearnGitLab|Add code to this project's repository"),
            trackLabel: 'add_code',
            url: CGI.unescape(url_helpers.ide_project_edit_path(project.full_path))
          }
        ]
      }
    end

    def project_section
      {
        title: s_('LearnGitLab|Configure a project'),
        description: s_("LearnGitLab|Complete these tasks first so you can enjoy GitLab's features to their fullest."),
        actions: [
          {
            title: s_('LearnGitLab|Invite your colleagues'),
            trackLabel: 'invite_your_colleagues',
            url: '#',
            urlType: 'invite',
            enabled: user.can?(:invite_member, project)
          },
          {
            title: s_("LearnGitLab|Set up your first project's CI/CD"),
            trackLabel: 'set_up_your_first_project_s_ci_cd',
            url: url_helpers.project_pipelines_path(project)
          },
          {
            title: s_('LearnGitLab|Start a free trial of GitLab Ultimate'),
            trackLabel: 'start_a_free_trial_of_gitlab_ultimate',
            url: url_helpers.new_trial_path(
              namespace_id: namespace.id, glm_source: GLM_SOURCE, glm_content: GLM_CONTENT
            ),
            # Free will need to also observe namespace.has_free_or_no_subscription?
            enabled: user.can?(:admin_namespace, namespace)
          }
        ],
        trialActions: trial_actions
      }
    end

    def plan_section
      {
        title: s_('LearnGitLab|Plan and execute work together'),
        description: s_("LearnGitLab|Create a workflow, and learn how GitLab features work together."),
        actions: [
          {
            title: s_('LearnGitLab|Create an issue'),
            trackLabel: 'create_an_issue',
            url: url_helpers.project_issues_path(project)
          },
          {
            title: s_('LearnGitLab|Submit a merge request (MR)'),
            trackLabel: 'submit_a_merge_request_mr',
            url: url_helpers.project_merge_requests_path(project)
          }
        ]
      }
    end

    def secure_deployment_section
      {
        title: s_('LearnGitLab|Secure your deployment'),
        descriptionIcon: 'license',
        description: s_(
          'LearnGitLab|Included in trial. Use GitLab to deploy your application, monitor its health, ' \
            'and keep it secure.'
        ),
        actions: [
          {
            title: s_('LearnGitLab|Scan dependencies for licenses'),
            trackLabel: 'scan_dependencies_for_licenses',
            url: url_helpers.help_page_path('user/compliance/license_scanning_of_cyclonedx_files/_index.md')
          },
          {
            title: s_('LearnGitLab|Scan dependencies for vulnerabilities'),
            trackLabel: 'scan_dependencies_for_vulnerabilities',
            url: url_helpers.project_security_configuration_path(project, anchor: 'dependency-scanning'),
            enabled: user.can?(:read_project_security_dashboard, project)
          },
          {
            title: s_('LearnGitLab|Analyze your application for vulnerabilities with DAST'),
            trackLabel: 'analyze_your_application_for_vulnerabilities_with_dast',
            url: url_helpers.project_security_configuration_path(project, anchor: 'dast'),
            enabled: user.can?(:read_project_security_dashboard, project)
          }
        ]
      }
    end

    def namespace
      project.namespace
    end

    def trial_actions
      [
        {
          title: s_('LearnGitLab|Add code owners'),
          trackLabel: 'add_code_owners',
          url: url_helpers.help_page_path('user/project/codeowners/_index.md', anchor: 'set-up-code-owners')
        },
        {
          title: s_('LearnGitLab|Enable require merge approvals'),
          trackLabel: 'enable_require_merge_approvals',
          url: url_helpers.help_page_path(
            'ci/testing/code_coverage/_index.md', anchor: 'add-a-coverage-check-approval-rule'
          )
        }
      ]
    end

    def url_helpers
      Gitlab::Routing.url_helpers
    end

    def user_access
      ::Gitlab::UserAccess.new(user, container: project)
    end

    def project_create_blob_path(project, ref)
      url_helpers.project_create_blob_path(project, ref)
    end
  end
end
