# frozen_string_literal: true

module Projects
  class GetStartedController < Projects::ApplicationController
    include ::Onboarding::SetRedirect
    include Gitlab::InternalEventsTracking

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user!
    before_action :verify_available!

    helper_method :onboarding_progress

    feature_category :onboarding
    urgency :low

    def show
      @get_started_presenter = ::Onboarding::GetStartedPresenter.new(current_user, project, onboarding_progress)
      @hide_importing_alert = true
    end

    def end_tutorial
      if onboarding_progress.update(ended_at: Time.current)
        percentage = ::Onboarding::Completion.new(project, current_user).get_started_percentage

        track_internal_event(
          "click_end_tutorial_button",
          user: current_user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: 'get_started',
            property: 'progress_percentage_on_end',
            value: percentage
          }
        )

        flash[:success] = s_("GetStarted|You've ended the tutorial.")
        flash.keep(:success)

        render json: { success: true, redirect_path: project_path(project) }
      else
        error =
          s_("GetStarted|There was a problem trying to end the tutorial. Please try again.")

        render json: { success: false, message: error }, status: :unprocessable_entity
      end
    end

    private

    def onboarding_progress
      # We only want to observe first level projects.
      # We do not care about any of their subgroup projects.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/537653#note_2478488770
      @onboarding_progress ||= ::Onboarding::Progress.find_by_namespace_id!(project.namespace)
    end

    def verify_available!
      access_denied! unless ::Onboarding::LearnGitlab.available?(project.namespace, current_user)
    end
  end
end
