# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Mcp::Administration::VerifyMcpServerSetup, :silence_stdout, feature_category: :mcp_server do
  let_it_be(:user, freeze: false) { create(:user, :admin, username: 'mcp_test_user') }

  let(:username) { user.username }
  let(:task) { described_class.new(username) }

  subject(:verify_setup) { task.execute }

  before do
    allow(::Gitlab::CurrentSettings).to receive(:mcp_server_enabled?).and_return(true)
  end

  describe '#check_mcp_server_enabled' do
    context 'when on SaaS' do
      before do
        stub_saas_features(mcp_server_saas_only: true)
      end

      it 'records info and skips the instance-level check' do
        verify_setup

        expect(task.diagnostics[:mcp_server_enabled]).to include(status: 'INFO')
        expect(task.diagnostics[:mcp_server_enabled][:message]).to include('SaaS')
      end

      context 'when the instance setting is disabled' do
        before do
          allow(::Gitlab::CurrentSettings).to receive(:mcp_server_enabled?).and_return(false)
        end

        it 'records info instead of failure' do
          verify_setup

          expect(task.diagnostics[:mcp_server_enabled]).to include(status: 'INFO')
        end
      end
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(mcp_server_saas_only: false)
      end

      it 'falls through to the instance-level check' do
        verify_setup

        expect(task.diagnostics[:mcp_server_enabled]).to include(status: 'PASS')
      end
    end
  end

  describe '#check_user_namespace_mcp_server_enabled' do
    context 'when on SaaS' do
      before do
        stub_saas_features(mcp_server_saas_only: true)
      end

      context 'when user belongs to a group with MCP server enabled' do
        before do
          allow_next_found_instance_of(User) do |found_user|
            allow(found_user).to receive(:any_group_with_mcp_server_enabled?).and_return(true)
          end
        end

        it 'records pass' do
          verify_setup

          expect(task.diagnostics[:user_namespace_mcp_server_enabled]).to include(status: 'PASS')
        end
      end

      context 'when user does not belong to any group with MCP server enabled' do
        before do
          allow_next_found_instance_of(User) do |found_user|
            allow(found_user).to receive(:any_group_with_mcp_server_enabled?).and_return(false)
          end
        end

        it 'records failure' do
          verify_setup

          expect(task.diagnostics[:user_namespace_mcp_server_enabled]).to include(status: 'FAIL')
        end
      end
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(mcp_server_saas_only: false)
      end

      it 'does not record the namespace mcp server enabled check' do
        verify_setup

        expect(task.diagnostics).not_to include(:user_namespace_mcp_server_enabled)
      end
    end
  end
end
