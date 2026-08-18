# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE-specific user_settings routing', feature_category: :system_access do
  describe '/-/user_settings/active_sessions/saml.json' do
    subject { get('/-/user_settings/active_sessions/saml.json') }

    it { is_expected.to route_to(controller: 'user_settings/active_sessions', action: 'saml', format: 'json') }
  end

  describe '/-/user_settings/active_sessions/saml' do
    subject { get('/-/user_settings/active_sessions/saml') }

    it { is_expected.to route_to('user_settings/active_sessions#saml') }
  end

  describe '/-/user_settings/active_sessions/saml.html' do
    subject { get('/-/user_settings/active_sessions/saml.html') }

    it { is_expected.not_to route_to('user_settings/active_sessions#saml') }
  end
end
