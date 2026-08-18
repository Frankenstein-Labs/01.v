# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::RevokeTokenService, feature_category: :workflow_catalog do
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, :with_oauth) }
  let_it_be(:user) { create(:user) }

  let(:registration) { instance_double(::Gitlab::Oauth::DynamicRegistrationClient) }

  subject(:result) do
    described_class.new(mcp_server: mcp_server, current_user: user).execute
  end

  before do
    allow(::Gitlab::Oauth::DynamicRegistrationClient).to receive(:new).and_return(registration)
    allow(registration).to receive(:discover_metadata).and_return({})
  end

  describe '#execute' do
    context 'when the user has no connection record' do
      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('No connection found for this MCP server')
      end
    end

    context 'when the user has a connection record' do
      let_it_be(:mcp_server_user) do
        create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user, token: 'access-token')
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'destroys the connection record' do
        expect { result }.to change { Ai::Catalog::McpServersUser.count }.by(-1)
      end

      context 'when destroy fails' do
        before do
          allow_next_found_instance_of(Ai::Catalog::McpServersUser) do |instance|
            allow(instance).to receive(:destroy).and_return(false)
          end
        end

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Failed to disconnect from MCP server')
        end

        it 'does not remove the connection record' do
          expect { result }.not_to change { Ai::Catalog::McpServersUser.count }
        end
      end

      context 'when the provider has a revocation endpoint' do
        before do
          allow(registration).to receive(:discover_metadata).and_return(
            'revocation_endpoint' => 'https://auth.example.com/oauth/revoke'
          )
          allow(Gitlab::HTTP).to receive(:post)
        end

        it 'posts to the revocation endpoint' do
          result

          expect(Gitlab::HTTP).to have_received(:post).with(
            'https://auth.example.com/oauth/revoke',
            hash_including(body: URI.encode_www_form(token: 'access-token'))
          )
        end

        it 'returns success' do
          expect(result).to be_success
        end

        context 'when the revocation request fails' do
          before do
            allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError, 'connection refused')
          end

          it 'still returns success' do
            expect(result).to be_success
          end

          it 'still destroys the local connection record' do
            expect { result }.to change { Ai::Catalog::McpServersUser.count }.by(-1)
          end

          it 'logs a warning' do
            expect(Gitlab::AppLogger).to receive(:warn).with(
              hash_including(
                message: 'Failed to revoke MCP server token at provider',
                mcp_server_id: mcp_server.id
              )
            )

            result
          end
        end
      end

      context 'when the provider has no revocation endpoint' do
        before do
          allow(registration).to receive(:discover_metadata).and_return({})
        end

        it 'does not make any HTTP requests' do
          expect(Gitlab::HTTP).not_to receive(:post)

          result
        end

        it 'returns success' do
          expect(result).to be_success
        end
      end
    end
  end
end
