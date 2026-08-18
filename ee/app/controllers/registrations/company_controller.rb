# frozen_string_literal: true

module Registrations
  class CompanyController < ApplicationController
    include OneTrustCSP
    include GoogleAnalyticsCSP
    include GoogleSyndicationCSP
    include ::Onboarding::SetRedirect
    include ::Onboarding::InProgress
    include ::Onboarding::StatusPresenterAccess

    layout 'minimal'

    before_action :verify_onboarding_enabled!
    before_action :authenticate_user!
    before_action :verify_in_onboarding_flow!

    feature_category :onboarding
    urgency :low, [:create]

    def new
      track_event('render', onboarding_status_presenter.tracking_label)
    end

    def create
      result = GitlabSubscriptions::CreateCompanyLeadService.new(user: current_user, params: permitted_params).execute

      if result.success?
        track_event('successfully_submitted_form', onboarding_status_presenter.tracking_label)

        response = Onboarding::StatusStepUpdateService.new(current_user, new_users_sign_up_group_path).execute

        redirect_to response[:step_url]
      else
        result.errors.each do |error|
          track_event("track_#{onboarding_status_presenter.tracking_label}_error", error.parameterize.underscore)
        end

        flash.now[:alert] = result.errors.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    private

    def permitted_params
      params.permit(
        *::Onboarding::StatusPresenter::PASSED_THROUGH_PARAMS,
        :company_name,
        :first_name,
        :last_name,
        :phone_number,
        :country,
        :state
      )
    end

    def track_event(action, label)
      ::Gitlab::Tracking.event(self.class.name, action, user: current_user, label: label)
    end
  end
end
