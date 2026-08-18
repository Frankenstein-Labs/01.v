# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServer, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').required }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to have_many(:mcp_servers_users).class_name('Ai::Catalog::McpServersUser') }
  end

  describe 'validations' do
    subject(:mcp_server) { build(:ai_catalog_mcp_server) }

    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:transport) }
    it { is_expected.to validate_presence_of(:auth_type) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(2_048) }
    it { is_expected.to validate_length_of(:url).is_at_most(2_048) }
    it { is_expected.to validate_length_of(:homepage_url).is_at_most(2_048) }
    it { is_expected.to validate_length_of(:oauth_client_id).is_at_most(255) }

    describe 'url validation' do
      context 'with local and external URLs specified' do
        using RSpec::Parameterized::TableSyntax

        where(:url, :allow_local_requests, :is_valid) do
          'http://example.com'        | false | true
          'https://example.com/path'  | false | true
          'http://localhost:3000'     | false | false
          'http://192.168.1.1'        | false | false
          'http://example.com'        | true | true
          'https://example.com/path'  | true | true
          'http://localhost:3000'     | true | true
          'http://192.168.1.1'        | true | true
        end

        with_them do
          it 'validates them' do
            Gitlab::CurrentSettings.update!(allow_local_requests_from_web_hooks_and_services: allow_local_requests)

            mcp_server.url = url

            expect(mcp_server.valid?).to eq(is_valid)
          end
        end
      end

      context 'with invalid URLs' do
        it 'rejects URLs with invalid schemes' do
          mcp_server.url = 'javascript:alert(1)'

          expect(mcp_server).not_to be_valid
          expect(mcp_server.errors[:url]).to include('is blocked: Only allowed schemes are http, https')
        end

        it 'rejects malformed URLs' do
          mcp_server.url = 'not a url'

          expect(mcp_server).not_to be_valid
          expect(mcp_server.errors[:url]).to include('is blocked: Only allowed schemes are http, https')
        end
      end

      context 'with uniqueness scoped to organization' do
        let_it_be(:organization1) { create(:organization) }
        let_it_be(:organization2) { create(:organization) }

        it 'allows the same URL for different organizations' do
          url = 'https://example.com/mcp-server'
          create(:ai_catalog_mcp_server, organization: organization1, url: url)
          mcp_server = build(:ai_catalog_mcp_server, organization: organization2, url: url)

          expect(mcp_server).to be_valid
        end

        it 'rejects duplicate URLs within the same organization' do
          url = 'https://example.com/mcp-server'
          create(:ai_catalog_mcp_server, organization: organization1, url: url)
          mcp_server = build(:ai_catalog_mcp_server, organization: organization1, url: url)

          expect(mcp_server).not_to be_valid
          expect(mcp_server.errors[:url]).to include('has already been taken')
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:transport).with_values(http: 0) }
    it { is_expected.to define_enum_for(:auth_type).with_values(oauth: 0, no_auth: 1) }
  end

  describe 'encryption' do
    it 'encrypts oauth_client_secret' do
      mcp_server = create(:ai_catalog_mcp_server, :with_oauth, oauth_client_secret: { 'secret' => 'value' })

      expect(mcp_server.encrypted_attribute?(:oauth_client_secret)).to be(true)
    end
  end

  describe '#http?' do
    it 'returns true when transport is http' do
      mcp_server = build(:ai_catalog_mcp_server, transport: :http)

      expect(mcp_server.http?).to be(true)
    end
  end

  describe '#oauth?' do
    it 'returns true when auth_type is oauth' do
      mcp_server = build(:ai_catalog_mcp_server, auth_type: :oauth)

      expect(mcp_server.oauth?).to be(true)
    end
  end

  describe '#no_auth?' do
    it 'returns true when auth_type is no_auth' do
      mcp_server = build(:ai_catalog_mcp_server, auth_type: :no_auth)

      expect(mcp_server.no_auth?).to be(true)
    end
  end

  describe 'associations with users' do
    let_it_be(:mcp_server) { create(:ai_catalog_mcp_server) }
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }

    before do
      create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user1)
      create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: user2)
    end

    it 'returns associated user settings' do
      expect(mcp_server.mcp_servers_users.map(&:user)).to contain_exactly(user1, user2)
    end
  end

  describe '.in_organization' do
    let_it_be(:organization1) { create(:organization) }
    let_it_be(:organization2) { create(:organization) }
    let_it_be(:mcp_server1) { create(:ai_catalog_mcp_server, organization: organization1, name: 'Server 1') }
    let_it_be(:mcp_server2) { create(:ai_catalog_mcp_server, organization: organization1, name: 'Server 2') }
    let_it_be(:mcp_server3) { create(:ai_catalog_mcp_server, organization: organization2, name: 'Server 3') }

    it 'returns MCP servers for the specified organization' do
      expect(described_class.in_organization(organization1)).to contain_exactly(mcp_server1, mcp_server2)
    end

    it 'does not return MCP servers from other organizations' do
      expect(described_class.in_organization(organization1)).not_to include(mcp_server3)
    end
  end

  describe '#connected_by_user?' do
    let_it_be(:mcp_server) { create(:ai_catalog_mcp_server) }
    let_it_be(:connected_user) { create(:user) }
    let_it_be(:other_user) { create(:user) }

    before_all do
      create(:ai_catalog_mcp_servers_user, mcp_server: mcp_server, user: connected_user)
    end

    it 'returns true when the user has a connection record' do
      expect(mcp_server.connected_by_user?(connected_user)).to be(true)
    end

    it 'returns false when the user has no connection record' do
      expect(mcp_server.connected_by_user?(other_user)).to be(false)
    end

    it 'returns false when user is nil' do
      expect(mcp_server.connected_by_user?(nil)).to be(false)
    end
  end
end
