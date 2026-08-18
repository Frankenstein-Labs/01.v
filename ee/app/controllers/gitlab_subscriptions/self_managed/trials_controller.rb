# frozen_string_literal: true

module GitlabSubscriptions
  module SelfManaged
    class TrialsController < ApplicationController
      include Gitlab::InternalEventsTracking
      include SafeFormatHelper

      layout 'minimal'

      feature_category :acquisition

      def new
        render GitlabSubscriptions::SelfManaged::TrialFormComponent.new(user: current_user)
      end

      def create
        result = GitlabSubscriptions::SelfManaged::CreateTrialService.new(
          params: create_params,
          user: current_user
        ).execute

        if result.success?
          flash[:success] = flash_success_message
          track_internal_event('sm_trial_create_form_success_banner_render', user: current_user)

          redirect_to dashboard_projects_path
        elsif result.reason == GitlabSubscriptions::SelfManaged::CreateTrialService::FORM_FAILURE
          flash.now[:alert] = result.message
          render GitlabSubscriptions::SelfManaged::TrialFormComponent.new(user: current_user)
        else
          render GitlabSubscriptions::SelfManaged::ResubmitComponent.new(
            hidden_fields: create_params.to_h,
            submit_path: self_managed_trials_path
          ).with_content(resubmit_error_content(result))
        end
      end

      private

      def create_params
        params.permit(
          :first_name, :last_name, :email_address, :company_name,
          :country, :state, :consent_to_marketing
        )
      end

      def flash_success_message
        # TODO Add exp date from license after success call and update flash message
        # https://gitlab.com/gitlab-org/gitlab/-/issues/585717
        message = s_(
          "Trial|You have successfully started an Ultimate trial for GitLab."
        )

        safe_format(message)
      end

      def resubmit_error_content(result)
        safe_format(
          result.message,
          tag_pair(support_link, :support_link_start, :support_link_end)
        )
      end

      def support_link
        helpers.link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
      end
    end
  end
end
