# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      class TrialFormComponent < ViewComponent::Base
        include TrialFormDisplayUtilities

        def initialize(**kwargs)
          @user = kwargs[:user]
          @eligible_namespaces = kwargs[:eligible_namespaces]
          @params = kwargs[:params]
        end

        private

        attr_reader :user, :eligible_namespaces, :params

        delegate :sprite_icon, to: :helpers

        def before_render
          content_for :body_class, 'duo-trials !gl-bg-brand-charcoal'
        end

        def before_form_content
          # no op
        end

        def form_data
          ::Gitlab::Json.generate(
            {
              userData: user_data,
              namespaceData: namespace_data,
              submitPath: submit_path,
              gtmSubmitEventLabel: 'saasDuoProTrialSubmit',
              border: false
            }
          )
        end

        def user_data
          {
            firstName: user.first_name,
            lastName: user.last_name,
            showNameFields: user.last_name.blank?,
            emailDomain: user.email_domain,
            companyName: user.company
          }
        end

        def submit_path
          trials_duo_pro_path(
            step: GitlabSubscriptions::Trials::DuoProCreateService::FULL,
            **params.slice(*::Onboarding::StatusPresenter::GLM_PARAMS)
          )
        end

        def namespace_data
          {
            # This may allow through an unprivileged submission of trial since we don't validate access on the passed in
            # namespace_id.
            # That is ok since we validate this on submission.
            initialValue: (namespace_id || single_eligible_namespace_id).to_s,
            anyTrialEligibleNamespaces: eligible_namespaces.any?,
            items: format_namespaces_for_selector(eligible_namespaces)
          }
        end

        def namespace_id
          params[:namespace_id]
        end

        def single_eligible_namespace_id
          return unless GitlabSubscriptions::Trials.single_eligible_namespace?(eligible_namespaces)

          eligible_namespaces.first&.id
        end
      end
    end
  end
end
