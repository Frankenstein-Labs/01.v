# frozen_string_literal: true

module Registrations
  module CompanyHelper
    def create_company_form_data(onboarding_status_presenter)
      ::Gitlab::Json.generate(
        {
          user: {
            firstName: current_user.first_name,
            lastName: current_user.last_name,
            companyName: nil,
            phoneNumber: nil,
            country: '',
            state: '',
            showNameFields: current_user.last_name.blank?,
            emailDomain: current_user.email_domain
          }.with_indifferent_access.merge(
            params.permit(:first_name, :last_name, :company_name, :phone_number, :country, :state)
                  .transform_keys { |key| key.to_s.camelize(:lower) }
          ),
          submitPath: users_sign_up_company_path(::Onboarding::StatusPresenter.passed_through_params(params)),
          showFormFooter: onboarding_status_presenter.show_company_form_footer?,
          trackActionForErrors: onboarding_status_presenter.tracking_label,
          trialDuration: ::GitlabSubscriptions::TrialDurationService.new.execute
        }
      )
    end
  end
end
