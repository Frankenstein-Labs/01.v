# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::SourceType, feature_category: :knowledge_graph do
  describe '.for_orbit_request', :allow_forgery_protection do
    let(:request) { instance_double(ActionDispatch::Request, env: env, session: session) }
    let(:session) { {} }
    let(:env) { {} }
    let(:oauth_access_token) { nil }

    subject(:source_type) do
      described_class.for_orbit_request(request: request, oauth_access_token: oauth_access_token)
    end

    context 'when request is frontend with valid CSRF token' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:session) { { _csrf_token: csrf_token } }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }

      it 'returns frontend' do
        expect(source_type).to eq(described_class::FRONTEND)
      end
    end

    context 'when request uses ai_workflows OAuth scope' do
      let(:oauth_access_token) { create(:oauth_access_token, scopes: [:ai_workflows]) }

      it 'returns dws' do
        expect(source_type).to eq(described_class::DWS)
      end
    end

    context 'when request is not frontend and token does not have ai_workflows scope' do
      let(:oauth_access_token) { create(:oauth_access_token, scopes: [:api]) }

      it 'returns rest' do
        expect(source_type).to eq(described_class::REST)
      end
    end

    context 'when request is frontend and ai_workflows token is also present' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:session) { { _csrf_token: csrf_token } }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }
      let(:oauth_access_token) { create(:oauth_access_token, scopes: [:ai_workflows]) }

      it 'prioritizes frontend' do
        expect(source_type).to eq(described_class::FRONTEND)
      end
    end

    context 'when request is frontend and a valid frontend_subtype is provided' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:session) { { _csrf_token: csrf_token } }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }

      subject(:source_type) do
        described_class.for_orbit_request(
          request: request,
          oauth_access_token: oauth_access_token,
          frontend_subtype: described_class::CODE_INTELLIGENCE
        )
      end

      it 'returns the subtype' do
        expect(source_type).to eq(described_class::CODE_INTELLIGENCE)
      end
    end

    context 'when request is frontend and an unknown frontend_subtype is provided' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:session) { { _csrf_token: csrf_token } }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }

      subject(:source_type) do
        described_class.for_orbit_request(
          request: request,
          oauth_access_token: oauth_access_token,
          frontend_subtype: 'unknown_type'
        )
      end

      it 'falls back to frontend' do
        expect(source_type).to eq(described_class::FRONTEND)
      end
    end

    context 'when request is not frontend and a frontend_subtype is provided' do
      subject(:source_type) do
        described_class.for_orbit_request(
          request: request,
          oauth_access_token: oauth_access_token,
          frontend_subtype: described_class::CODE_INTELLIGENCE
        )
      end

      it 'ignores the subtype and returns rest' do
        expect(source_type).to eq(described_class::REST)
      end
    end
  end

  describe '.for_mcp_request' do
    let(:request) { instance_double(ActionDispatch::Request, env: {}, session: {}) }
    let(:oauth_access_token) { nil }

    subject(:mcp_source_type) do
      described_class.for_mcp_request(request: request, oauth_access_token: oauth_access_token)
    end

    context 'when oauth_access_token is nil' do
      it 'returns MCP without calling for_orbit_request' do
        expect(described_class).not_to receive(:for_orbit_request)

        expect(mcp_source_type).to eq(described_class::MCP)
      end
    end

    context 'when oauth_access_token has ai_workflows scope' do
      let(:oauth_access_token) { create(:oauth_access_token, scopes: [:ai_workflows]) }

      it 'returns DWS' do
        expect(mcp_source_type).to eq(described_class::DWS)
      end
    end

    context 'when oauth_access_token has other scopes' do
      let(:oauth_access_token) { create(:oauth_access_token, scopes: [:api]) }

      it 'returns MCP' do
        expect(mcp_source_type).to eq(described_class::MCP)
      end
    end
  end

  describe '.frontend_request?' do
    let(:request) { instance_double(ActionDispatch::Request, env: env, session: session) }
    let(:session) { {} }
    let(:env) { {} }

    subject(:frontend_request) { described_class.frontend_request?(request) }

    context 'when request is nil' do
      let(:request) { nil }

      it 'returns false' do
        expect(frontend_request).to be(false)
      end
    end

    context 'when request has no CSRF token header' do
      let(:env) { {} }

      it 'returns false' do
        expect(frontend_request).to be(false)
      end
    end

    context 'when request has CSRF header but session is nil' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }
      let(:session) { nil }

      it 'returns false' do
        expect(frontend_request).to be(false)
      end
    end

    context 'when request has CSRF header but no session CSRF token' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }
      let(:session) { {} }

      it 'returns false' do
        expect(frontend_request).to be(false)
      end
    end

    context 'when request has CSRF header and session token but CSRF verification fails' do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }
      let(:session) { { _csrf_token: csrf_token } }

      before do
        allow(Gitlab::RequestForgeryProtection).to receive(:verified?).and_return(false)
      end

      it 'returns false' do
        expect(frontend_request).to be(false)
      end
    end

    context 'when request has valid CSRF header and matching session token', :allow_forgery_protection do
      let(:csrf_token) { SecureRandom.base64(ActionController::RequestForgeryProtection::AUTHENTICITY_TOKEN_LENGTH) }
      let(:env) { { 'HTTP_X_CSRF_TOKEN' => csrf_token } }
      let(:session) { { _csrf_token: csrf_token } }

      it 'returns true' do
        expect(frontend_request).to be(true)
      end
    end
  end
end
