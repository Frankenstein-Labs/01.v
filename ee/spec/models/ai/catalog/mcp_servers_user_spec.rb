# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServersUser, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').required }
    it { is_expected.to belong_to(:mcp_server).class_name('Ai::Catalog::McpServer') }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:ai_catalog_mcp_server_id) }
    it { is_expected.to validate_presence_of(:user_id) }

    describe 'uniqueness' do
      let_it_be(:mcp_server) { create(:ai_catalog_mcp_server) }
      let_it_be(:user) { create(:user) }

      before do
        create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user)
      end

      it 'validates uniqueness of user_id scoped to mcp_server_id' do
        duplicate = build(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to include('has already been taken')
      end

      it 'allows the same user with different mcp_servers' do
        different_mcp_server = create(:ai_catalog_mcp_server)
        association = build(:ai_catalog_mcp_servers_user, mcp_server: different_mcp_server, user: user)

        expect(association).to be_valid
      end

      it 'allows the same mcp_server with different users' do
        different_user = create(:user)
        association = build(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: different_user)

        expect(association).to be_valid
      end
    end
  end

  describe 'encryption' do
    let(:mcp_servers_user) { create(:ai_catalog_mcp_servers_user, token: { 'access_token' => 'secret123' }) }

    it 'encrypts token' do
      expect(mcp_servers_user.encrypted_attribute?(:token)).to be(true)
    end

    it 'encrypts refresh_token' do
      mcp_servers_user = create(:ai_catalog_mcp_servers_user, refresh_token: { 'refresh_token' => 'secret456' })

      expect(mcp_servers_user.encrypted_attribute?(:refresh_token)).to be(true)
    end
  end

  describe 'user-specific MCP server settings' do
    let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, :with_oauth) }
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }

    it 'stores separate tokens for different users' do
      user1_settings = create(
        :ai_catalog_mcp_servers_user,
        mcp_server: mcp_server,
        user: user1,
        token: { 'access_token' => 'user1_token' }
      )
      user2_settings = create(
        :ai_catalog_mcp_servers_user,
        mcp_server: mcp_server,
        user: user2,
        token: { 'access_token' => 'user2_token' }
      )

      expect(user1_settings.token).to eq({ 'access_token' => 'user1_token' })
      expect(user2_settings.token).to eq({ 'access_token' => 'user2_token' })
    end

    it 'stores separate refresh tokens for different users' do
      user1_settings = create(
        :ai_catalog_mcp_servers_user,
        mcp_server: mcp_server,
        user: user1,
        refresh_token: { 'refresh_token' => 'user1_refresh' }
      )
      user2_settings = create(
        :ai_catalog_mcp_servers_user,
        mcp_server: mcp_server,
        user: user2,
        refresh_token: { 'refresh_token' => 'user2_refresh' }
      )

      expect(user1_settings.refresh_token).to eq({ 'refresh_token' => 'user1_refresh' })
      expect(user2_settings.refresh_token).to eq({ 'refresh_token' => 'user2_refresh' })
    end
  end
end
