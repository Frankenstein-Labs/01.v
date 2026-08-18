# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Auth::RequestAuthenticator, feature_category: :system_access do
  let(:env) do
    {
      'rack.input' => ''
    }
  end

  let(:request) { ActionDispatch::Request.new(env) }

  subject { Gitlab::Auth::RequestAuthenticator.new(request) }

  describe '#find_sessionless_user' do
    let_it_be(:geo_token_user) { build(:user) }
    let_it_be(:dependency_proxy_user) { build(:user) }

    it 'returns geo_token user first' do
      allow_next_instance_of(::Gitlab::Auth::RequestAuthenticator) do |instance|
        allow(instance).to receive(:find_user_from_geo_token).and_return(geo_token_user)
        allow(instance).to receive(:find_user_from_dependency_proxy_token).and_return(dependency_proxy_user)
      end

      expect(subject.find_sessionless_user(:graphql_api)).to eq geo_token_user
    end

    it 'returns nil if no user found' do
      expect(subject.find_sessionless_user(:graphql_api)).to be_nil
    end

    it 'rescue Gitlab::Auth::AuthenticationError exceptions' do
      allow_next_instance_of(::Gitlab::Auth::RequestAuthenticator) do |instance|
        allow(instance).to receive(:find_user_from_geo_token).and_raise(Gitlab::Auth::UnauthorizedError)
      end

      expect(subject.find_sessionless_user(:graphql_api)).to be_nil
    end
  end

  describe '#graphql_authorization_scopes' do
    it 'includes :ai_features and :ai_workflows' do
      scopes = subject.send(:graphql_authorization_scopes)
      expect(scopes).to include(:ai_features, :ai_workflows)
    end

    it 'includes base scopes' do
      scopes = subject.send(:graphql_authorization_scopes)
      expect(scopes).to include(:api, :read_api)
    end
  end
end
