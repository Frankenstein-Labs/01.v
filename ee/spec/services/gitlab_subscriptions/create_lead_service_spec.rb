# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CreateLeadService, feature_category: :acquisition do
  let_it_be(:user) { create(:user, last_name: 'Jones') }

  describe '#execute' do
    let(:expected_params) do
      {
        company_name: 'Gitlab',
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: '1111111111',
        country: 'US',
        state: 'CA',
        glm_content: 'free-billing',
        glm_source: 'about.gitlab.com',
        work_email: user.email,
        uid: user.id,
        setup_for_company: nil,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        opt_in: true,
        with_add_on: true,
        add_on_name: 'duo_enterprise'
      }
    end

    let(:company_params) { { trial_user: ActionController::Parameters.new(expected_params).permit! } }

    subject(:execute) { described_class.new.execute(company_params) }

    it 'successfully creates a trial' do
      allow(Gitlab::SubscriptionPortal::Client)
        .to receive(:generate_trial_lead)
        .with(company_params)
        .and_return({ success: true })

      expect(execute).to be_success
    end

    it 'errors while creating trial' do
      allow(Gitlab::SubscriptionPortal::Client)
        .to receive(:generate_trial_lead)
        .and_return({ success: false, data: { errors: '_fail_' } })

      expect(execute).to be_error.and have_attributes(message: '_fail_')
    end
  end
end
