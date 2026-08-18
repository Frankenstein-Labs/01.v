# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::TokenActor, feature_category: :system_access do
  let(:saml_provider) { create(:saml_provider) }
  let(:group) { saml_provider.group }

  subject(:token_actor) { described_class.new(token) }

  describe 'as a policy actor' do
    let(:token) { group.saml_discovery_token }

    it { is_expected.to be_a(PolicyActor) }

    it 'is granted access by the saml provider policy' do
      expect(token_actor.can?(:sign_in_with_saml_provider, saml_provider)).to be(true)
    end

    it 'is not authenticated via CI job token' do
      expect(token_actor.from_ci_job_token?).to be(false)
    end
  end

  context 'valid token' do
    let(:token) { group.saml_discovery_token }

    it 'is valid for the group' do
      is_expected.to be_valid_for(group)
    end
  end

  context 'invalid token' do
    let(:token) { 'abcdef' }

    it 'is invalid for the group' do
      is_expected.not_to be_valid_for(group)
    end
  end

  context 'missing token' do
    let(:token) { nil }

    it 'is invalid for the group' do
      is_expected.not_to be_valid_for(group)
    end
  end

  context 'when geo prevents saml_provider from having a token' do
    let(:token) { nil }
    let(:group) { double(:group, saml_discovery_token: nil) }

    it 'prevents nil token from allowing access' do
      is_expected.not_to be_valid_for(group)
    end
  end
end
