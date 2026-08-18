# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe Gitlab::Auth::RemoteDevelopment::AuthFinders, feature_category: :workspaces do
  include ::Gitlab::Auth::AuthFinders
  include described_class

  let(:request) { ActionDispatch::Request.new(env) }
  let(:env) do
    {
      'rack.input' => ''
    }
  end

  describe '#workspace_token_from_authorization_token' do
    subject(:result) { workspace_token_from_authorization_token }

    let_it_be(:workspace_token) { create(:workspace_token) }

    context 'when the header contains a valid workspace token' do
      before do
        request.headers[Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER] = workspace_token.token
      end

      it 'returns the workspace token' do
        expect(result).to eq(workspace_token)
      end
    end

    context 'when the header contains an invalid workspace token' do
      before do
        request.headers[Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER] = 'invalid-token'
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when the header is missing' do
      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when the header is empty' do
      before do
        request.headers[Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER] = ''
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when the header is nil' do
      before do
        request.headers[Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER] = nil
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end
end
