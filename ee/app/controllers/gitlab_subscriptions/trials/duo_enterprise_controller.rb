# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseController < ApplicationController
      include GitlabSubscriptions::Trials::DuoCommon

      feature_category :acquisition
      urgency :low

      def new
        track_event('render_duo_enterprise_trial_page')

        render GitlabSubscriptions::Trials::DuoEnterprise::TrialFormComponent
                 .new(
                   user: current_user,
                   eligible_namespaces: eligible_namespaces,
                   params: form_params
                 )
      end

      def create
        result = GitlabSubscriptions::Trials::DuoEnterpriseCreateService.new(
          step: general_params[:step], params: create_params, user: current_user
        ).execute

        if result.success?
          # lead and trial created
          flash[:success] = success_flash_message(result.payload[:add_on_purchase])

          redirect_to group_settings_gitlab_duo_path(result.payload[:namespace])
        elsif result.reason == GitlabSubscriptions::Trials::DuoEnterpriseCreateService::NOT_FOUND
          render_404
        else
          render GitlabSubscriptions::Trials::DuoEnterprise::CreationFailureComponent.new(
            params: form_params, result: result
          )
        end
      end

      private

      def eligible_namespaces
        Users::AddOnTrialEligibleNamespacesFinder.new(current_user, add_on: :duo_enterprise).execute
      end
      strong_memoize_attr :eligible_namespaces

      def create_params
        form_params.to_h.symbolize_keys
      end

      def form_params
        params.permit(
          *::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id, :first_name, :last_name, :company_name,
          :phone_number, :country, :state
        )
      end

      def success_flash_message(add_on_purchase)
        safe_format(
          s_(
            'DuoEnterpriseTrial|You have successfully started a Duo Enterprise trial that will ' \
              'expire on %{exp_date}. To give members access to new GitLab Duo Enterprise features, ' \
              '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Enterprise seats.'
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long_unpadded)
        )
      end
    end
  end
end
