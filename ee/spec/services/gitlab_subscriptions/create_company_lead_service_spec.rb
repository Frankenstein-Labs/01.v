# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CreateCompanyLeadService, feature_category: :acquisition do
  let_it_be_with_reload(:user) do
    create(
      :user,
      last_name: 'Jones',
      onboarding_status_email_opt_in: true,
      onboarding_status_initial_registration_type: 'trial',
      onboarding_status_registration_type: 'trial',
      onboarding_status_setup_for_company: true
    )
  end

  describe '#execute', :saas do
    using RSpec::Parameterized::TableSyntax

    let(:trial_registration) { true }
    let(:base_params) do
      {
        uid: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        work_email: user.email,
        setup_for_company: user.onboarding_status_setup_for_company,
        opt_in: user.onboarding_status_email_opt_in,
        role: user.onboarding_status_role_name,
        preferred_language: 'English',
        provider: 'gitlab',
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        with_add_on: true,
        add_on_name: 'duo_enterprise',
        jtbd: nil,
        comment: '_comment_'
      }
    end

    shared_examples 'correct client attributes' do
      let(:params) do
        base_params.merge(jtbd: nil)
      end

      before do
        subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

        stub_request(:post, "#{subscription_portal_url}/leads/gitlab_com/ultimates")
        stub_saas_features(onboarding: true)
      end

      it do
        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:generate_trial_lead)
          .with(params.merge(client_params))
          .and_call_original

        described_class.new(user: user, params: params).execute
      end
    end

    context 'when creating an automatic trial' do
      before do
        user.update!(
          onboarding_status_initial_registration_type: 'free',
          onboarding_status_glm_source: 'some_source',
          onboarding_status_glm_content: 'some_content'
        )
      end

      it_behaves_like 'correct client attributes' do
        let(:client_params) do
          {
            product_interaction: 'SaaS Trial - defaulted',
            glm_source: 'some_source',
            glm_content: 'some_content'
          }
        end
      end
    end

    context 'when creating a trial' do
      before do
        user.update!(
          onboarding_status_glm_source: 'some_source',
          onboarding_status_glm_content: 'some_content'
        )
      end

      it_behaves_like 'correct client attributes' do
        let(:client_params) do
          {
            product_interaction: 'SaaS Trial',
            glm_source: 'some_source',
            glm_content: 'some_content'
          }
        end
      end
    end

    it 'successfully creates a trial' do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial_lead)
        .with(base_params.merge(product_interaction: 'SaaS Trial'))
        .and_return({ success: true })

      result = described_class.new(user: user, params: {
        first_name: user.first_name,
        last_name: user.last_name,
        jobs_to_be_done_other: '_comment_',
        jtbd: '_jtbd_'
      }).execute

      expect(result.success?).to be true
    end

    context 'when creating trial fails without an error message from the client' do
      it 'error while creating trial' do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial_lead).and_return({ success: false })

        result = described_class.new(user: user, params: {}).execute

        expect(result.success?).to be false
        expect(result.reason).to eq(:submission_failed)
        expect(result.errors).to match(['Submission failed'])
      end
    end

    context 'when creating trial fails with an error message from the client' do
      it 'error while creating trial' do
        message = "Last name can't be blank"
        response = Net::HTTPUnprocessableEntity.new(1.0, '422', 'Error')
        gitlab_http_response = instance_double(
          HTTParty::Response,
          code: response.code,
          parsed_response: { errors: message }.stringify_keys,
          response: response,
          body: {},
          headers: nil
        )
        # going deeper than usual here to verify the API doesn't change and break this area that relies on
        # symbols for `error`
        allow(Gitlab::HTTP).to receive(:post).and_return(gitlab_http_response)

        result = described_class.new(user: user, params: {}).execute

        expect(result.success?).to be false
        expect(result.reason).to eq(:submission_failed)
        expect(result.errors).to match([message])
      end
    end
  end
end
