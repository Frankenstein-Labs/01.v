# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::RemoteDevelopment::Internal::Agents::Agentw::ServerConfig, feature_category: :workspaces do
  let(:jwt_auth_headers) do
    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, "aud" => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )

    { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token }
  end

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }

  let(:stub_service_payload) do
    {
      api_external_url: "external url",
      oauth_redirect_url: "redirect url",
      some_key: "some value"
    }
  end

  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::Main,
      domain_main_class_args: {
        request: instance_of(Grape::Request)
      }
    }
  end

  let(:stub_service_response) { ServiceResponse.success(payload: stub_service_payload) }

  before do
    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)
  end

  # @param [Hash] headers
  # @return [Integer] response status code
  def send_request(headers: {})
    get api("/internal/agents/agentw/server_config"), headers: headers.reverse_merge(jwt_auth_headers)
  end

  shared_examples "authorization" do
    context "when not authenticated" do
      it "returns 401" do
        send_request(headers: { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => "" })

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe "GET /internal/agents/agentw/server_config" do
    include_examples "authorization"

    context "with valid auth" do
      it "returns expected response structure with correct status" do
        expect(RemoteDevelopment::CommonService).to receive(:execute).with(expected_service_args) do
          stub_service_response
        end

        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({
          "api_external_url" => "external url",
          "oauth_redirect_url" => "redirect url",
          "some_key" => "some value"
        })
      end
    end
  end
end
