# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::TermsAndConditionsController, :enable_admin_mode, feature_category: :"self-hosted_models" do
  let(:admin) { create(:admin) }
  let(:duo_features_enabled) { true }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  before do
    sign_in(admin)
    stub_ee_application_setting(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'returns 404' do
    context 'when the user is not authorized' do
      it 'performs the right authorization correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(admin, :manage_self_hosted_models_settings).and_return(false)

        perform_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST #toggle_beta_models' do
    subject :perform_request do
      post admin_ai_duo_self_hosted_toggle_beta_models_path
    end

    context 'if a testing terms acceptance record exists' do
      before do
        create(:ai_testing_terms_acceptances, user_id: admin.id, user_email: admin.email)
      end

      it 'destroys the record' do
        expect(::Ai::SelfHostedModels::TestingTermsAcceptance::DestroyService).to receive(:new)
          .with(instance_of(::Ai::TestingTermsAcceptance)).and_call_original

        expect { perform_request }.to change { ::Ai::TestingTermsAcceptance.count }.by(-1)
      end
    end

    context 'if a testing terms acceptance record does not exist' do
      it 'creates the record' do
        expect(::Ai::SelfHostedModels::TestingTermsAcceptance::CreateService).to receive(:new)
          .with(admin).and_call_original

        expect { perform_request }.to change { ::Ai::TestingTermsAcceptance.count }.by(1)
      end
    end

    it_behaves_like 'returns 404'
  end
end
