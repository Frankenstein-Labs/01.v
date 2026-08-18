# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      class CreationFailureComponent < ViewComponent::Base
        include SafeFormatHelper

        def initialize(result:, params:)
          @result = result
          @params = params
        end

        def call
          render component_instance
        end

        private

        attr_reader :result, :params

        def component_instance
          case result.reason
          when GitlabSubscriptions::Trials::DuoEnterpriseCreateService::LEAD_FAILED
            ResubmitComponent.new(
              hidden_fields: lead_failed_hidden_fields,
              submit_path: submit_path(GitlabSubscriptions::Trials::DuoEnterpriseCreateService::RESUBMIT_LEAD)
            ).with_content(result.errors.to_sentence)
          else
            ResubmitComponent.new(
              hidden_fields: trial_failed_hidden_fields,
              submit_path: submit_path(GitlabSubscriptions::Trials::DuoEnterpriseCreateService::RESUBMIT_TRIAL)
            ).with_content(trial_error_content)
          end
        end

        def trial_failed_hidden_fields
          { namespace_id: result.payload[:namespace_id] }
        end
        alias_method :namespace_param, :trial_failed_hidden_fields

        def lead_failed_hidden_fields
          params.slice(
            :first_name, :last_name, :company_name, :phone_number, :country, :state
          ).merge(namespace_param)
        end

        def submit_path(step)
          trials_duo_enterprise_path(
            step: step,
            **params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS)
          )
        end

        def trial_error_content
          if result.reason == GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR
            safe_format(
              errors_message,
              tag_pair(support_link, :support_link_start, :support_link_end)
            )
          else
            result.errors.to_sentence
          end.concat('.')
        end

        def support_link
          link_to('', Gitlab::Saas.customer_support_url, target: '_blank', rel: 'noopener noreferrer')
        end

        def errors_message
          support_message = _(
            'Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance'
          )

          [support_message, result.errors.to_sentence.presence].compact.join(': ')
        end
      end
    end
  end
end
