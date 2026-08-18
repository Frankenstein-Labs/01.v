# frozen_string_literal: true

module Projects
  class LearnGitlabController < Projects::ApplicationController
    include ::Onboarding::SetRedirect
    include Gitlab::InternalEventsTracking

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user! # since it is skipped in inherited controller
    before_action :verify_learn_gitlab_available!

    helper_method :onboarding_progress

    feature_category :onboarding
    urgency :low

    def show
      @hide_importing_alert = true
    end

    def end_tutorial
      if onboarding_progress.update(ended_at: Time.current)
        percentage = ::Onboarding::Completion.new(project, current_user).percentage

        track_internal_event(
          "click_end_tutorial_button",
          user: current_user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'learn_gitlab',
            property: 'progress_percentage_on_end',
            value: percentage
          }
        )

        flash[:success] = s_("LearnGitlab|You've ended the Learn GitLab tutorial.")
        flash.keep(:success)

        render json: { success: true, redirect_path: project_path(project) }
      else
        error =
          s_("LearnGitlab|There was a problem trying to end the Learn GitLab tutorial. Please try again.")

        render json: { success: false, message: error }, status: :unprocessable_entity
      end
    end

    private

    def onboarding_progress
      @onboarding_progress ||= ::Onboarding::Progress.find_by_namespace_id!(project.namespace)
    end

    def verify_learn_gitlab_available!
      access_denied! unless ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
    end
  end
end
