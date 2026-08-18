# frozen_string_literal: true

require('spec_helper')

RSpec.describe UserSettings::ActiveSessionsController, feature_category: :system_access do
  let_it_be(:user) { create(:user) }

  describe '/saml' do
    subject(:get_saml) { get :saml }

    let(:saml_provider) { create(:saml_provider) }
    let(:other_saml_provider) { create(:saml_provider) }
    let(:first_saml_sign_in) { Time.utc(2024, 2, 2, 1, 44) }
    let(:json_response) { Gitlab::Json.parse(response.body).map(&:with_indifferent_access) }

    around do |ex|
      travel_to(first_saml_sign_in + 6.hours) { ex.run }
    end

    it 'responds with 404' do
      get_saml

      expect(response).to redirect_to(new_user_session_path)
    end

    context 'with signed-in user' do
      before do
        sign_in(user)
      end

      context 'with no current SAML sessions' do
        it 'responds with empty array' do
          get_saml

          expect(json_response).to eq([])
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with SAML sign-in session data' do
        # mimic the actions of ::Gitlab::Auth::GroupSaml::SsoState.update_active, but
        # ensure it is hooked into the controller test session rather than initializing its
        # own thread-local session
        before do
          key = ::Gitlab::Auth::GroupSaml::SsoState::SESSION_STORE_KEY
          store = Gitlab::NamespacedSessionStore.new(key, session)
          store[saml_provider.id] = first_saml_sign_in
          store[other_saml_provider.id] = (first_saml_sign_in + 4.hours)
        end

        it 'responds with JSON of current SAML sessions' do
          get_saml

          expect(json_response).to match_array(
            [
              {
                provider_id: saml_provider.id,
                time_remaining_ms: 18.hours.in_milliseconds
              },
              {
                provider_id: other_saml_provider.id,
                time_remaining_ms: 22.hours.in_milliseconds
              }
            ]
          )

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end
