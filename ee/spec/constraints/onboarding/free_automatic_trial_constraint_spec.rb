# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FreeAutomaticTrialConstraint, feature_category: :onboarding do
  subject(:constraint) { described_class.new }

  let(:user) { nil }
  let(:setup_for_company) { 'true' }
  let(:warden) { instance_double(Warden::Proxy, user: user) }
  let(:request) do
    env = Rack::MockRequest.env_for(
      '/users/sign_up/welcome',
      method: 'POST',
      params: { onboarding_status_setup_for_company: setup_for_company, _method: 'patch' }
    )
    env['warden'] = warden
    ActionDispatch::Request.new(env)
  end

  before do
    stub_saas_features(onboarding: true)
  end

  describe '#matches?' do
    context 'when warden is not present' do
      let(:request) do
        env = Rack::MockRequest.env_for('/users/sign_up/welcome', method: 'POST')
        ActionDispatch::Request.new(env)
      end

      it 'returns false' do
        expect(constraint.matches?(request)).to be(false)
      end
    end

    context 'when user is not present' do
      it 'returns false' do
        expect(constraint.matches?(request)).to be(false)
      end
    end

    context 'when user is present' do
      let_it_be(:user) { create(:user, onboarding_status_registration_type: 'free') }

      context 'when setup_for_company is true in the form body' do
        it 'returns true' do
          expect(constraint.matches?(request)).to be(true)
        end
      end

      context 'when setup_for_company is false in the form body' do
        let(:setup_for_company) { 'false' }

        it 'returns false' do
          expect(constraint.matches?(request)).to be(false)
        end
      end

      context 'when setup_for_company is absent' do
        let(:request) do
          env = Rack::MockRequest.env_for('/users/sign_up/welcome', method: 'POST')
          env['warden'] = warden
          ActionDispatch::Request.new(env)
        end

        it 'returns false' do
          expect(constraint.matches?(request)).to be(false)
        end
      end

      context 'when user is not a free registration' do
        let_it_be(:user) { create(:user, onboarding_status_registration_type: 'subscription_sm') }

        it 'returns false even when setup_for_company is true' do
          expect(constraint.matches?(request)).to be(false)
        end
      end
    end
  end
end
