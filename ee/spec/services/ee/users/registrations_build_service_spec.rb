# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::RegistrationsBuildService, feature_category: :system_access do
  describe '#execute' do
    let(:extra_params) { {} }
    let(:params) do
      build_stubbed(:user)
        .slice(:first_name, :last_name, :username, :email, :password)
        .merge(extra_params)
    end

    subject(:built_user) { described_class.new(nil, params).execute }

    context 'with onboarding_status_email_opt_in param' do
      let(:extra_params) { { onboarding_status_email_opt_in: true } }
      let(:onboarding_enabled?) { true }

      before do
        stub_saas_features(onboarding: onboarding_enabled?)
      end

      context 'when the saas feature onboarding is available' do
        it 'creates a user with onboarding_status_email_opt_in set' do
          expect(built_user.onboarding_status_email_opt_in).to be(true)
        end
      end

      context 'when the saas feature onboarding is not available' do
        let(:onboarding_enabled?) { false }

        it 'creates a user with onboarding_status_email_opt_in set' do
          expect(built_user.onboarding_status_email_opt_in).to be_nil
        end
      end
    end
  end
end
