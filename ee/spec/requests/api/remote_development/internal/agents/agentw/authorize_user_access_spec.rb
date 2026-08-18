# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::RemoteDevelopment::Internal::Agents::Agentw::AuthorizeUserAccess, feature_category: :workspaces do
  let(:jwt_auth_headers) do
    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, "aud" => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )

    { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token }
  end

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }

  let(:workspace_host) { "workspace.example.com" }
  let(:user_id) { 123 }

  let(:stub_service_payload) { { some_key: "some_value" } }

  let(:expected_service_args) do
    {
      domain_main_class: ::RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Main,
      domain_main_class_args: {
        workspace_host: workspace_host,
        user_id: user_id
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
    get api("/internal/agents/agentw/authorize_user_access"),
      params: { workspace_host: workspace_host, user_id: user_id },
      headers: headers.reverse_merge(jwt_auth_headers)
  end

  shared_examples "authorization" do
    context "when not authenticated" do
      it "returns 401" do
        send_request(headers: { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => "" })

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe "GET /internal/agents/agentw/authorize_user_access" do
    include_examples "authorization"

    context "with valid auth" do
      context "when service call is successful" do
        it "calls the service with correct parameters and returns the service payload" do
          expect(RemoteDevelopment::CommonService)
            .to receive(:execute).with(expected_service_args).and_return(stub_service_response)

          send_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({ "some_key" => "some_value" })
        end
      end
    end
  end
end
