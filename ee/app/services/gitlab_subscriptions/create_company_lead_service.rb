# frozen_string_literal: true

module GitlabSubscriptions
  class CreateCompanyLeadService
    def initialize(user:, params:)
      @user = user
      merged_params = params.merge(hardcoded_values).merge(user_values)
      @params = remapping_for_api(merged_params)
    end

    def execute
      build_product_interaction

      GitlabSubscriptions::CreateLeadService.new.execute(
        @params.merge(product_interaction: @product_interaction).to_h
      )
    end

    private

    attr_reader :user

    def hardcoded_values
      {
        provider: 'gitlab',
        skip_email_confirmation: true,
        gitlab_com_trial: true
      }
    end

    def user_values
      {
        uid: user.id,
        work_email: user.email,
        setup_for_company: user.onboarding_status_setup_for_company,
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in,
        role: user.onboarding_status_role_name,
        jtbd: user.onboarding_status_registration_objective_name,
        **glm_params
      }
    end

    def glm_params
      { glm_content: user.onboarding_status_glm_content, glm_source: user.onboarding_status_glm_source }.compact
    end

    def remapping_for_api(params)
      params[:comment] ||= params.delete(:jobs_to_be_done_other)
      params
    end

    def build_product_interaction
      @product_interaction = ::Onboarding::UserStatus.new(user).product_interaction
    end
  end
end
