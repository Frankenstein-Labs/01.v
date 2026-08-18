# frozen_string_literal: true

module Oauth
  class McpConnectorsAuthController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_read_ai_catalog_mcp_server!
    rescue_from OAuth2::Error, with: :handle_oauth_error

    feature_category :workflow_catalog

    def connect
      mcp_server = ::Ai::Catalog::McpServer.find(mcp_server_params[:id])

      result = ::Ai::Catalog::McpServers::ConnectService.new(
        mcp_server: mcp_server,
        redirect_uri: oauth_mcp_connectors_callback_url,
        return_to: mcp_server_params[:return_to] || root_path
      ).execute

      if result.success?
        session[:"mcp_oauth_code_verifier_#{mcp_server.id}"] = result.payload[:code_verifier]
        redirect_to result.payload[:authorization_url], allow_other_host: true
      else
        redirect_back fallback_location: root_path, alert: result.message
      end
    end

    def disconnect
      mcp_server = ::Ai::Catalog::McpServer.find(mcp_server_params[:id])

      result = ::Ai::Catalog::McpServers::RevokeTokenService.new(
        mcp_server: mcp_server,
        current_user: current_user
      ).execute

      if result.success?
        render json: {}, status: :ok
      else
        render json: { message: result.message }, status: :unprocessable_entity
      end
    end

    def callback
      state = ::Gitlab::Oauth::ClientState.from_state(mcp_server_params[:state])

      unless state.valid?
        redirect_to root_path, alert: _('OAuth state mismatch. Please try again.')
        return
      end

      mcp_server = ::Ai::Catalog::McpServer.find(state[:mcp_server_id])
      code_verifier = session.delete(:"mcp_oauth_code_verifier_#{mcp_server.id}")

      result = ::Ai::Catalog::McpServers::CallbackService.new(
        mcp_server: mcp_server,
        current_user: current_user,
        code: mcp_server_params[:code],
        redirect_uri: oauth_mcp_connectors_callback_url,
        code_verifier: code_verifier
      ).execute

      if result.success?
        redirect_to state.return_to || root_path, notice: _('Successfully connected to MCP server')
      else
        redirect_to state.return_to || root_path, alert: result.message
      end
    end

    private

    def mcp_server_params
      params.permit(:id, :return_to, :state, :code)
    end

    def authorize_read_ai_catalog_mcp_server!
      render_404 unless can?(current_user, :read_ai_catalog_mcp_server, Current.organization)
    end

    def handle_oauth_error
      redirect_to root_path, alert: _('OAuth error occurred. Please try again.')
    end
  end
end
