# frozen_string_literal: true

# EE:SaaS
module GitlabSubscriptions
  module Trials
    class DuoProController < ApplicationController
      include GitlabSubscriptions::Trials::DuoCommon

      feature_category :acquisition
      urgency :low

      def new
        track_event('render_duo_pro_trial_page')

        render GitlabSubscriptions::Trials::DuoPro::TrialFormComponent.new(
          user: current_user,
          eligible_namespaces: eligible_namespaces,
          params: form_params
        )
      end

      def create
        result = GitlabSubscriptions::Trials::DuoProCreateService.new(
          step: general_params[:step], params: create_params, user: current_user
        ).execute

        if result.success?
          # lead and trial created
          flash[:success] = success_flash_message(result.payload[:add_on_purchase])

          redirect_to group_settings_gitlab_duo_path(result.payload[:namespace])
        elsif result.reason == GitlabSubscriptions::Trials::DuoProCreateService::NOT_FOUND
          render_404
        else
          render GitlabSubscriptions::Trials::DuoPro::CreationFailureComponent.new(
            params: form_params, result: result
          )
        end
      end

      private

      def eligible_namespaces
        Users::AddOnTrialEligibleNamespacesFinder.new(current_user, add_on: :duo).execute
      end
      strong_memoize_attr :eligible_namespaces

      def create_params
        form_params.to_h.symbolize_keys
      end

      def form_params
        params.permit(
          *::Onboarding::StatusPresenter::GLM_PARAMS,
          :namespace_id, :first_name, :last_name, :company_name, :phone_number, :country, :state
        )
      end

      def success_flash_message(add_on_purchase)
        safe_format(
          s_(
            'DuoProTrial|You have successfully started a Duo Pro trial that will ' \
              'expire on %{exp_date}. To give members access to new GitLab Duo Pro features, ' \
              '%{assign_link_start}assign them%{assign_link_end} to GitLab Duo Pro seats.'
          ),
          success_doc_link,
          exp_date: l(add_on_purchase.expires_on.to_date, format: :long_unpadded)
        )
      end
    end
  end
end
