# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Mcp::Base, feature_category: :mcp_server do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp]) }

  describe 'POST /mcp' do
    context 'when gitlab.com', :saas do
      let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }

      before do
        stub_saas_features(mcp_server_saas_only: true)
      end

      context 'when a root group has mcp_server_enabled' do
        before do
          group.namespace_settings.reload.update!(mcp_server_enabled: true)
        end

        it 'ignores the instance-level mcp_server_enabled setting' do
          stub_application_setting(mcp_server_enabled: false)

          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-06-18' } }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when no root group has mcp_server_enabled' do
        before do
          group.namespace_settings.reload.update!(mcp_server_enabled: false)
        end

        it 'returns not_found' do
          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-06-18' } }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when not gitlab.com' do
      let_it_be(:group) { create(:group, developers: user) }

      context 'when Gitlab::CurrentSettings.mcp_server_enabled is true' do
        before do
          stub_application_setting(mcp_server_enabled: true)
        end

        it 'returns ok' do
          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-06-18' } }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when Gitlab::CurrentSettings.mcp_server_enabled is false' do
        before do
          stub_application_setting(mcp_server_enabled: false)
        end

        it 'returns not_found' do
          post api('/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-06-18' } }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when logging the denial reason' do
      let_it_be(:group) { create(:group, developers: user) }

      def expect_denial_reason(reason)
        expect_next_instance_of(Gitlab::Mcp::Logger) do |logger|
          expect(logger).to receive(:info).with(
            message: 'MCP server not available',
            event_name: 'permission_denied',
            ai_component: 'mcp_server',
            denial_reason: reason,
            Labkit::Fields::GL_USER_ID => user.id
          )
        end

        post api('/mcp', user, oauth_access_token: access_token),
          params: { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-11-25' } }
      end

      context 'on gitlab.com with no enabled namespace', :saas do
        before do
          stub_saas_features(mcp_server_saas_only: true)
        end

        it 'logs :no_enabled_namespace' do
          expect_denial_reason(:no_enabled_namespace)
        end
      end
    end
  end
end
