# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemAccess::GroupMicrosoftApplication, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'has one graph_access_token' do
      token = create(:system_access_group_microsoft_graph_access_token)
      app = build_stubbed(:system_access_group_microsoft_application, graph_access_token: token)

      expect(app.graph_access_token).to eql(token)
    end

    it 'can access graph_access_token via legacy association' do
      token = create(:system_access_group_microsoft_graph_access_token)
      app = build_stubbed(:system_access_group_microsoft_application, system_access_microsoft_graph_access_token: token)

      expect(app.system_access_microsoft_graph_access_token).to eql(token)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:tenant_xid) }
    it { is_expected.to validate_presence_of(:client_xid) }
    it { is_expected.to validate_presence_of(:encrypted_client_secret) }
    it { is_expected.to validate_presence_of(:login_endpoint) }
    it { is_expected.to validate_presence_of(:graph_endpoint) }
    it { is_expected.to validate_length_of(:client_secret).is_at_most(255) }

    context 'when validating client_secret length' do
      it 'does not invalidate existing records' do
        app = create(:system_access_group_microsoft_application)
        app.client_secret = 'A' * 260
        app.save!(validate: false)

        expect(app.reload).to be_valid
      end
    end

    context 'when validating login_endpoint' do
      it 'is invalid if not an https URL' do
        app = build(:system_access_group_microsoft_application, login_endpoint: 'http://example.com')
        expect(app).not_to be_valid
        expect(app.errors[:login_endpoint]).to include('is blocked: Only allowed schemes are https')
      end

      it 'is valid with an https URL' do
        app = build(:system_access_group_microsoft_application, login_endpoint: 'https://example.com')
        expect(app).to be_valid
      end
    end

    context 'when validating graph_endpoint' do
      it 'is invalid if not an https URL' do
        app = build(:system_access_group_microsoft_application, graph_endpoint: 'http://example.com')
        expect(app).not_to be_valid
        expect(app.errors[:graph_endpoint]).to include('is blocked: Only allowed schemes are https')
      end

      it 'is valid with an https URL' do
        app = build(:system_access_group_microsoft_application, graph_endpoint: 'https://example.com')
        expect(app).to be_valid
      end
    end
  end

  describe '#build_system_access_microsoft_graph_access_token' do
    let(:instance) { create(:system_access_group_microsoft_application) }

    it 'builds a new SystemAccess::GroupMicrosoftGraphAccessToken with inherited group' do
      graph_token = instance.build_system_access_microsoft_graph_access_token(
        expires_in: 2.hours,
        token: 'abc123'
      )

      expect(graph_token).to be_a(SystemAccess::GroupMicrosoftGraphAccessToken)
      expect(graph_token.group).to eq(instance.group)
      expect(graph_token).to be_valid
    end

    it 'allows overriding group if necessary' do
      group2 = build_stubbed(:group)

      graph_token = instance.build_system_access_microsoft_graph_access_token(
        group: group2,
        expires_in: 2.hours,
        token: 'abc123'
      )

      expect(graph_token).to be_a(SystemAccess::GroupMicrosoftGraphAccessToken)
      expect(graph_token.group).to eq(group2)
      expect(graph_token).to be_valid
    end
  end
end
