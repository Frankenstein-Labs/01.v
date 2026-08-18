# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Saml::SsoEnforcer, feature_category: :system_access do
  include LoginHelpers

  let(:user) { create :user }
  let(:session) { {} }
  let(:stubbed_saml_config) do
    stub_omniauth_saml_config(
      enabled: true,
      auto_link_saml_user: false,
      allow_single_sign_on: ['saml'],
      providers: [mock_saml_config]
    )
  end

  around do |example|
    Gitlab::Session.with_session(session) do
      example.run
    end
  end

  before do
    stubbed_saml_config
  end

  def update_session(time: Time.current, session_not_on_or_after: nil)
    Gitlab::Auth::Saml::SsoState.new(provider_id: :saml)
      .update_active(time: time, session_not_on_or_after: session_not_on_or_after)
  end

  subject(:enforcer) { described_class.new user: user }

  describe '#active_session?' do
    it 'returns false if nothing has been stored' do
      expect(enforcer).not_to be_active_session
    end

    it 'returns true if a sign in has been recorded' do
      update_session

      expect(enforcer).to be_active_session
    end

    it 'returns false if the sign in predates the session timeout' do
      update_session

      days_after_timeout = Gitlab::Auth::GroupSaml::SsoEnforcer::DEFAULT_SESSION_TIMEOUT + 2.days
      travel_to(days_after_timeout.from_now) do
        expect(enforcer).not_to be_active_session
      end
    end

    context 'when a session timeout is specified' do
      subject(:enforcer) { described_class.new user: user, session_timeout: 1.hour }

      it 'returns true within timeout' do
        update_session

        expect(enforcer).to be_active_session
      end

      it 'returns false after timeout elapses' do
        update_session

        travel_to(2.hours.from_now) do
          expect(enforcer).not_to be_active_session
        end
      end
    end

    context 'when session expiration is provided as SAML response' do
      let(:session_timeout) { 2.hours }

      subject(:enforcer) { described_class.new user: user, session_timeout: session_timeout }

      it 'returns false if session has expired' do
        update_session(time: Time.current, session_not_on_or_after: 30.minutes.from_now.iso8601)

        travel_to(1.hour.from_now) do
          expect(enforcer).not_to be_active_session
        end
      end

      it 'returns true if session has not expired' do
        update_session(time: Time.current, session_not_on_or_after: 4.hours.from_now.iso8601)

        travel_to(3.hours.from_now) do
          expect(enforcer).to be_active_session
        end
      end
    end
  end

  describe '#access_restricted?' do
    let_it_be(:user) { create(:user, identities: [build(:identity, provider: 'saml')]) }

    context 'when sso enforcement is enabled' do
      before do
        stub_application_setting(password_authentication_enabled_for_web: false)
      end

      context 'when there is no active saml session' do
        it 'returns true' do
          expect(enforcer).to be_access_restricted
        end
      end

      context 'when there is active saml session' do
        context 'when the session timeout is the default' do
          before do
            update_session
          end

          it 'returns false' do
            expect(enforcer).not_to be_access_restricted
          end
        end

        context 'when a session timeout is specified' do
          subject(:enforcer) { described_class.new user: user, session_timeout: 1.hour }

          it 'returns false within timeout' do
            update_session

            expect(enforcer).not_to be_access_restricted
          end

          it 'returns true after timeout elapses' do
            update_session

            travel_to(2.hours.from_now) do
              expect(enforcer).to be_access_restricted
            end
          end
        end
      end
    end

    context 'when saml_provider is nil' do
      let(:saml_provider) { nil }

      it 'returns false' do
        expect(enforcer).not_to be_access_restricted
      end
    end

    context 'when sso enforcement is disabled' do
      before do
        stub_application_setting(password_authentication_enabled_for_web: true)
      end

      it 'returns false' do
        expect(enforcer).not_to be_access_restricted
      end
    end

    context 'when saml_provider is disabled' do
      let(:stubbed_saml_config) do
        stub_omniauth_saml_config(
          enabled: false,
          auto_link_saml_user: false,
          allow_single_sign_on: ['saml'],
          providers: [mock_saml_config]
        )
      end

      specify do
        expect(enforcer).not_to be_access_restricted
      end
    end
  end
end
