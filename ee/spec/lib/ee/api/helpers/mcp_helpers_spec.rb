# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Helpers::McpHelpers, feature_category: :mcp_server do
  let(:helper_class) do
    Class.new do
      include EE::API::Helpers::McpHelpers

      attr_accessor :access_token

      def initialize(token = nil)
        @access_token = token
      end
    end
  end

  let(:helper) { helper_class.new(access_token) }
  let(:access_token) { nil }

  describe '#mcp_request?' do
    subject { helper.mcp_request? }

    context 'when access_token is nil' do
      let(:access_token) { nil }

      it { is_expected.to be false }
    end

    context 'when access_token has MCP scope' do
      let(:access_token) { create(:oauth_access_token, scopes: [:mcp]) }

      it { is_expected.to be true }
    end

    context 'when access_token has both MCP and API scopes' do
      let(:access_token) { create(:oauth_access_token, scopes: [:mcp, :api]) }

      it { is_expected.to be true }
    end

    context 'when access_token has API no MCP scope' do
      let(:access_token) { create(:oauth_access_token, scopes: [:api]) }

      it { is_expected.to be false }
    end
  end
end
