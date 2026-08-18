# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe API::RemoteDevelopment::Internal::Agents::Agentw::AgentInfo, feature_category: :workspaces do
  let(:jwt_auth_headers) do
    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, "aud" => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )

    { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token }
  end

  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }

  let_it_be(:workspace) { create(:workspace) }
  let_it_be(:workspace_token) { create(:workspace_token, workspace: workspace) }

  before do
    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)
  end

  # @param [Hash] headers
  # @return [Integer] response status code
  def send_request(headers: {})
    get api("/internal/agents/agentw/agent_info"), headers: headers.reverse_merge(jwt_auth_headers)
  end

  shared_examples "authorization" do
    context "when not authenticated" do
      it "returns 401" do
        send_request(headers: { Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => "" })

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  describe "GET /internal/agents/agentw/agent_info" do
    include_examples "authorization"

    context "with valid auth" do
      context "when workspace token is provided and valid" do
        it "returns workspace id with correct status" do
          send_request(headers: { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => workspace_token.token })

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            "workspace_id" => workspace.id
          })
        end
      end

      context "when workspace token header is missing" do
        it "returns 401" do
          send_request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when workspace token is invalid" do
        it "returns 401" do
          send_request(headers: { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => "invalid-token" })

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when workspace token is empty" do
        it "returns 401" do
          send_request(headers: { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => "" })

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context "when workspace token is nil" do
        it "returns 401" do
          send_request(headers: { Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => nil })

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end
end
