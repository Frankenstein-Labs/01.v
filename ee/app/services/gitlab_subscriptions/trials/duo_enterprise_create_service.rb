# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoEnterpriseCreateService
      include Gitlab::Utils::StrongMemoize

      # Failure/error reasons
      LEAD_FAILED = :lead_failed
      TRIAL_FAILED = :trial_failed
      NOT_FOUND = :not_found

      # Flow steps
      FULL = 'full'
      RESUBMIT_LEAD = 'resubmit_lead'
      RESUBMIT_TRIAL = 'resubmit_trial'

      def initialize(step:, params:, user:)
        @step = step
        @params = params
        @user = user
      end

      def execute
        case step
        when FULL
          full_flow
        when RESUBMIT_LEAD
          submit_lead_and_trial
        when RESUBMIT_TRIAL
          resubmit_trial
        else
          not_found
        end
      end

      private

      attr_reader :user, :params, :step, :group_created

      def full_flow
        if existing_namespace_provided?
          submit_lead_and_trial
        else
          not_found
        end
      end

      def existing_namespace_provided?
        params[:namespace_id].present?
      end

      def valid_namespace_exists?
        namespace.present?
      end

      def namespace
        namespaces_eligible_for_trial.find_by_id(params[:namespace_id])
      end
      strong_memoize_attr :namespace

      def submit_lead_and_trial
        return not_found unless valid_namespace_exists?

        result = GitlabSubscriptions::Trials::CreateAddOnLeadService.new.execute({ trial_user: lead_params })

        if result.success?
          track_event('duo_enterprise_lead_creation_success')
          submit_trial
        else
          track_event('duo_enterprise_lead_creation_failure')

          ServiceResponse.error(
            message: result.message,
            reason: LEAD_FAILED,
            payload: { namespace_id: namespace.id }
          )
        end
      end

      def lead_params
        attrs = {
          work_email: user.email,
          uid: user.id,
          namespace_id: namespace.id,
          setup_for_company: user.onboarding_status_setup_for_company,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          existing_plan: namespace.actual_plan_name,
          provider: 'gitlab',
          product_interaction: 'duo_enterprise_trial',
          add_on_name: 'duo_enterprise',
          preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
          opt_in: user.onboarding_status_email_opt_in
        }

        params.slice(
          *::Onboarding::StatusPresenter::GLM_PARAMS,
          :company_name, :first_name, :last_name, :phone_number,
          :country, :state
        ).merge(attrs)
      end

      def resubmit_trial
        return not_found unless valid_namespace_exists?

        submit_trial
      end

      def submit_trial
        params[:namespace_id] = namespace.id

        result = GitlabSubscriptions::Trials::ApplyDuoEnterpriseService.new(
          uid: user.id,
          trial_user_information: trial_params
        ).execute

        if result.success?
          track_event('duo_enterprise_trial_registration_success')

          ServiceResponse.success(
            message: 'Trial applied',
            payload: { namespace: namespace, add_on_purchase: result.payload[:add_on_purchase] }
          )
        else
          track_event('duo_enterprise_trial_registration_failure')

          ServiceResponse.error(
            message: result.message,
            reason: result.reason || TRIAL_FAILED,
            payload: { namespace_id: namespace.id }
          )
        end
      end

      def trial_params
        gl_com_params = { gitlab_com_trial: true, sync_to_gl: true }
        namespace_params = {
          namespace: namespace.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: namespace.actual_plan.name)
        }

        params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS, :namespace_id)
              .merge(gl_com_params).merge(namespace_params).to_h.symbolize_keys
      end

      def namespaces_eligible_for_trial
        Users::AddOnTrialEligibleNamespacesFinder.new(user, add_on: :duo_enterprise).execute
      end

      def not_found
        ServiceResponse.error(message: 'Not found', reason: NOT_FOUND)
      end

      def track_event(action)
        Gitlab::InternalEvents.track_event(action, user: user, namespace: namespace)
      end
    end
  end
end
