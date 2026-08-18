# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::DocsClient, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:options) { {} }
  let(:expected_request_body) { default_body_params }

  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:expected_request_headers) { { 'header' => 'value' } }

  let(:default_body_params) do
    {
      type: described_class::DEFAULT_TYPE,
      metadata: {
        source: described_class::DEFAULT_SOURCE,
        version: Gitlab.version_info.to_s
      },
      payload: {
        query: "anything"
      }
    }
  end

  let(:expected_response) do
    { "foo" => "bar" }
  end

  let(:self_hosted_url) { 'http://local-aigw:5052' }
  let(:cloud_connector_url) { 'https://staging.cloud.gitlab.com' }
  let(:request_url) { "#{self_hosted_url}/v1/search/gitlab-docs" }
  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  before do
    allow(user).to receive_messages(governing_namespace: group, allowed_to_use: auth_response)
    allow(Gitlab::AiGateway).to receive(:headers)
      .with(user: user, unit_primitive_name: :duo_classic_chat, ai_feature_name: :chat,
        organization_id: user.governing_namespace&.organization_id,
        namespace_id: nil, project_id: nil, governing_namespace_id: user.governing_namespace&.id)
      .and_return(expected_request_headers)
    allow(Gitlab::AiGateway).to receive_messages(
      self_hosted_url: self_hosted_url,
      cloud_connector_url: cloud_connector_url
    )
  end

  describe '#search', :with_cloud_connector do
    before do
      stub_request(:post, request_url)
        .with(
          body: expected_request_body.to_json,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: response_headers
        )
    end

    subject(:result) do
      described_class.new(user, tracking_context: tracking_context).search(query: 'anything', **options)
    end

    it 'returns response', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/463071' do
      expect(Gitlab::HTTP).to receive(:post).with(
        anything,
        hash_including(timeout: Gitlab::AiGateway.timeout)
      ).and_call_original
      expect(result.parsed_response).to eq(expected_response)
    end

    context 'when duo chat is self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat) }

      it 'returns response for duo_chat' do
        expect(Gitlab::HTTP).to receive(:post).with(
          anything,
          hash_including(timeout: Gitlab::AiGateway.timeout)
        ).and_call_original
        expect(result.parsed_response).to eq(expected_response)
      end
    end

    context 'when duo chat is vendored' do
      let(:request_url) { "#{cloud_connector_url}/v1/search/gitlab-docs" }
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :vendored) }

      it 'returns response for vendored duo_chat' do
        expect(Gitlab::HTTP).to receive(:post).with(
          anything,
          hash_including(timeout: Gitlab::AiGateway.timeout)
        ).and_call_original
        expect(result.parsed_response).to eq(expected_response)
      end
    end

    context 'when governing_namespace is nil' do
      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
        allow(Gitlab::AiGateway).to receive(:headers)
          .with(user: user, unit_primitive_name: :duo_classic_chat, ai_feature_name: :chat,
            organization_id: nil, namespace_id: nil, project_id: nil, governing_namespace_id: nil)
          .and_return(expected_request_headers)
      end

      it 'passes nil organization_id' do
        expect(result.parsed_response).to eq(expected_response)
      end
    end

    context 'when namespace_id, project_id, and governing_namespace_id are provided' do
      subject(:result) do
        described_class.new(
          user,
          tracking_context: tracking_context,
          namespace_id: 10,
          project_id: 20,
          governing_namespace_id: 30
        ).search(query: 'anything', **options)
      end

      before do
        allow(Gitlab::AiGateway).to receive(:headers)
          .with(hash_including(namespace_id: 10, project_id: 20, governing_namespace_id: 30))
          .and_return(expected_request_headers)
      end

      it 'forwards them to Gitlab::AiGateway.headers' do
        result
        expect(Gitlab::AiGateway).to have_received(:headers).with(hash_including(namespace_id: 10, project_id: 20,
          governing_namespace_id: 30))
      end
    end
  end
end
