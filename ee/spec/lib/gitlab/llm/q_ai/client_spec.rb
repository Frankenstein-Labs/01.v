# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::QAi::Client, feature_category: :ai_agents do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be_with_reload(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:oauth_app) { create(:doorkeeper_application) }

  let(:ai_settings) { ::Ai::Setting.for_organization(user.organization) }
  let(:aigw_headers) { { "header" => "value" } }
  let(:expected_unit_primitive) { :amazon_q_integration }
  let(:expected_headers) do
    aigw_headers.merge({ 'X-Gitlab-Unit-Primitive' => expected_unit_primitive.to_s })
  end

  let(:response) { 'response' }
  let(:role_arn) { 'role_arn' }
  let(:event_id) { 'Quick Action' }
  let(:secret) { 'secret' }
  let(:logger) { instance_double(Gitlab::Llm::Logger) }

  before do
    allow(user).to receive(:governing_namespace).and_return(group)
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    allow(Doorkeeper::OAuth::Helpers::UniqueToken).to receive(:generate).and_return('1234')

    allow(Gitlab::AiGateway).to receive(:headers)
      .with(user: user, unit_primitive_name: expected_unit_primitive,
        organization_id: user.governing_namespace&.organization_id,
        governing_namespace_id: user.governing_namespace&.id)
      .and_return(aigw_headers)
  end

  describe '#create_event' do
    subject(:create_event) do
      described_class.new(user)
        .create_event(
          payload: {},
          role_arn: '5678',
          event_id: event_id
        )
    end

    let(:status) { 204 }
    let(:body) { nil }
    let(:headers) { { 'Content-Type' => "application/json" } }

    before do
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/events")
        .with(body: {
          payload: {},
          code: '1234',
          role_arn: '5678',
          event_id: event_id
        }.to_json, headers: expected_headers).to_return(body: body, status: status, headers: headers)

      ai_settings.update!(
        amazon_q_service_account_user_id: service_account.id,
        amazon_q_oauth_application_id: oauth_app.id
      )
    end

    it 'makes expected HTTP post request' do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: status,
          event_name: 'response_received'))

      response = create_event
      expect(response.code).to eq(204)
      expect(response.body).to be_empty
    end

    context 'with failed response' do
      let(:status) { 500 }
      let(:body) { { detail: "failed request" }.to_json }

      it 'logs a 500 error' do
        expect(logger).to receive(:error)
          .with(a_hash_including(
            message: "Error response from AI Gateway",
            ai_component: 'abstraction_layer',
            status: status,
            body: "failed request"))

        response = create_event
        expect(response.code).to eq(500)
      end
    end

    it 'creates an auth grant with the correct scopes', :aggregate_failures do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: 204,
          event_name: 'response_received'))

      expect { create_event }.to change { OauthAccessGrant.count }.by(1)
      grant = OauthAccessGrant.find_by(resource_owner: service_account, application: oauth_app)
      expect(grant.scopes.to_s).to eq("api read_repository write_repository user:#{user.id}")
    end

    context 'when governing_namespace is nil' do
      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
        allow(Gitlab::AiGateway).to receive(:headers)
          .with(user: user, unit_primitive_name: expected_unit_primitive,
            organization_id: nil, governing_namespace_id: nil)
          .and_return(aigw_headers)
      end

      it 'passes nil organization_id to headers' do
        allow(logger).to receive(:conditional_info)
        expect(create_event.code).to eq(204)
      end
    end
  end

  describe '#test_connection' do
    subject(:test_connection) { described_class.new(user).test_connection(role_arn: role_arn) }

    let(:status) { 200 }
    let(:body) { {}.to_json }
    let(:headers) { { 'Content-Type' => "application/json" } }

    before do
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application/verify")
        .with(body: {
          role_arn: role_arn,
          code: '1234'
        }.to_json, headers: expected_headers).to_return(body: body, status: status, headers: headers)

      ai_settings.update!(
        amazon_q_service_account_user_id: service_account.id,
        amazon_q_oauth_application_id: oauth_app.id
      )
    end

    it 'makes expected HTTP post request' do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: status,
          event_name: 'response_received'))

      response = test_connection
      expect(response.code).to eq(200)
    end

    context 'with failed response' do
      let(:status) { 500 }
      let(:body) { { detail: "failed request" }.to_json }

      it 'logs a 500 error' do
        expect(logger).to receive(:error)
          .with(a_hash_including(
            message: "Error response from AI Gateway",
            ai_component: 'abstraction_layer',
            status: status,
            body: "failed request"))

        response = test_connection
        expect(response.code).to eq(500)
      end
    end

    it 'creates an auth grant with the correct scopes', :aggregate_failures do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: status,
          event_name: 'response_received'))

      expect { test_connection }.to change { OauthAccessGrant.count }.by(1)
      grant = OauthAccessGrant.find_by(resource_owner: service_account, application: oauth_app)
      expect(grant.scopes.to_s).to eq("api read_repository write_repository user:#{user.id}")
    end
  end

  describe '#perform_create_auth_application' do
    subject(:perform_create_auth_application) do
      described_class.new(user)
        .perform_create_auth_application(oauth_app, secret, role_arn)
    end

    before do
      payload = {
        client_id: oauth_app.uid.to_s,
        client_secret: secret,
        redirect_url: oauth_app.redirect_uri,
        instance_url: Gitlab.config.gitlab.url,
        role_arn: role_arn
      }

      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application")
        .with(body: payload.to_json)
        .to_return(body: response)
    end

    it 'makes expected HTTP post request' do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: "Received successful response from AI Gateway",
          ai_component: 'abstraction_layer',
          status: 200,
          event_name: 'response_received'))

      expect(perform_create_auth_application.parsed_response).to eq(response)
    end
  end

  describe '#perform_delete_auth_application' do
    subject(:perform_delete_auth_application) do
      described_class.new(user).perform_delete_auth_application(role_arn)
    end

    before do
      payload = {
        role_arn: role_arn
      }

      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application/delete")
        .with(body: payload.to_json)
        .to_return(body: response)
    end

    it 'makes expected HTTP post request' do
      expect(logger).to receive(:conditional_info)
        .with(user, a_hash_including(
          message: 'Received successful response from AI Gateway',
          ai_component: 'abstraction_layer',
          status: 200,
          event_name: 'response_received'))

      expect(perform_delete_auth_application.parsed_response).to eq(response)
    end
  end
end
