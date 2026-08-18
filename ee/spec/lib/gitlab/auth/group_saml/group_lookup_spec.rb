# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::GroupLookup do
  let(:query_string) { 'group_path=the-group' }
  let(:path_info) { double }

  def lookup(params = {})
    @lookup ||= begin
      env = {
        "rack.input" => double,
        'PATH_INFO' => path_info
      }.merge(params)

      described_class.new(env)
    end
  end

  context 'on request path' do
    let(:path_info) { '/users/auth/group_saml' }

    it 'can detect group_path from rack.input body params' do
      lookup('REQUEST_METHOD' => 'POST', 'rack.input' => StringIO.new(query_string), 'CONTENT_TYPE' => 'multipart/form-data')

      expect(lookup.path).to eq 'the-group'
    end

    it 'can detect group_path from query params' do
      lookup("QUERY_STRING" => query_string)

      expect(lookup.path).to eq 'the-group'
    end
  end

  context 'on callback path' do
    let(:path_info) { '/groups/callback-group/-/saml/callback' }

    it 'can extract group_path from PATH_INFO' do
      expect(lookup.path).to eq 'callback-group'
    end

    it 'does not allow params to take precedence' do
      lookup("QUERY_STRING" => query_string)

      expect(lookup.path).to eq 'callback-group'
    end
  end

  it 'looks up group by path' do
    group = create(:group)
    allow(lookup).to receive(:path) { group.path }

    expect(lookup.group).to be_a(Group)
  end

  it 'exposes saml_provider' do
    saml_provider = create(:saml_provider)
    allow(lookup).to receive(:group) { saml_provider.group }

    expect(lookup.saml_provider).to be_a(SamlProvider)
  end

  context 'on metadata path' do
    let(:path_info) { '/users/auth/group_saml/metadata' }
    let(:saml_provider) { create(:saml_provider) }
    let(:group) { saml_provider.group }
    let(:group_params) { { group_path: group.full_path } }

    describe '#token_discoverable?' do
      it 'returns false when missing the discovery token' do
        lookup("QUERY_STRING" => group_params.to_query)

        expect(lookup).not_to be_token_discoverable
      end

      it 'returns false for incorrect discovery token' do
        query_string = group_params.merge(token: 'wrongtoken').to_query
        lookup("QUERY_STRING" => query_string)

        expect(lookup).not_to be_token_discoverable
      end

      it 'returns true when discovery token matches' do
        query_string = group_params.merge(token: group.saml_discovery_token).to_query
        lookup("QUERY_STRING" => query_string)

        expect(lookup).to be_token_discoverable
      end
    end
  end
end
