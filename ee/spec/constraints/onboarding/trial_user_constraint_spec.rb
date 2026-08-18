# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::TrialUserConstraint, feature_category: :onboarding do
  subject(:constraint) { described_class.new }

  let(:user) { nil }
  let(:warden) { instance_double(Warden::Proxy, user: user) }
  let(:request) do
    env = Rack::MockRequest.env_for('/', method: 'GET')
    env['warden'] = warden
    ActionDispatch::Request.new(env)
  end

  describe '#matches?' do
    context 'when warden is not present' do
      let(:request) do
        env = Rack::MockRequest.env_for('/', method: 'GET')
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
      let_it_be_with_reload(:user) { create(:user) }

      context 'when user is not a trial user' do
        it 'returns false' do
          expect(constraint.matches?(request)).to be(false)
        end
      end

      context 'when user is a trial user' do
        before do
          user.update!(onboarding_status_registration_type: ::Onboarding::REGISTRATION_TYPE[:trial])
        end

        it 'is truthy' do
          expect(constraint.matches?(request)).to be_truthy
        end
      end
    end
  end
end
