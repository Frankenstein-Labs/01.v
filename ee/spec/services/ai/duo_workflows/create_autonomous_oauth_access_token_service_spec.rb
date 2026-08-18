# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateAutonomousOauthAccessTokenService, feature_category: :duo_agent_platform do
  describe 'ALLOWED_SCOPES' do
    it 'is restricted to ai_workflows only' do
      expect(described_class::ALLOWED_SCOPES).to eq(::Gitlab::Auth::AI_WORKFLOW_SCOPES)
    end

    it 'does not include mcp, api, or dynamic user scopes' do
      expect(described_class::ALLOWED_SCOPES).not_to include('mcp', 'api', 'read_api', 'user:*')
    end
  end

  describe '#execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be_with_reload(:service_account) { create(:user, :service_account) }
    let_it_be_with_reload(:oauth_app) do
      create(:doorkeeper_application, scopes: %w[ai_workflows mcp user:*])
    end

    subject(:response) do
      described_class.new(
        service_account: service_account,
        organization: organization,
        trigger_source: :scheduled
      ).execute
    end

    before do
      stub_feature_flags(ai_settings_organization_scoped_lookup: false)
      service_account.update!(organization_id: organization.id) if service_account&.persisted?
    end

    context 'when service account and oauth app exist' do
      before do
        ::Ai::Setting.for_organization(organization).update!(duo_workflow_oauth_application_id: oauth_app.id)
      end

      it 'creates a new oauth access token' do
        expect { response }.to change { OauthAccessToken.count }.by(1)
        expect(response).to be_success

        oauth_token = OauthAccessToken.last
        expect(oauth_token.resource_owner_id).to eq(service_account.id)
        expect(oauth_token.scopes).to contain_exactly('ai_workflows')
      end

      it 'does not include a user:ID scope' do
        response

        oauth_token = OauthAccessToken.last
        expect(oauth_token.scopes.to_a).not_to include(a_string_matching(/^user:/))
      end

      it 'sets token expiry to 1 hour' do
        response

        oauth_token = OauthAccessToken.last
        expect(oauth_token.expires_in).to eq(1.hour.to_i)
      end

      it 'creates an autonomous_oauth_token_created audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'autonomous_oauth_token_created',
            author: service_account,
            scope: service_account,
            target: service_account,
            message: 'Created autonomous OAuth token for Duo workflow',
            additional_details: hash_including(
              scopes: include('ai_workflows'),
              expires_in: 3600,
              trigger_source: 'scheduled'
            )
          )
        )

        response
      end

      context 'when a container is provided' do
        let_it_be(:project) { create(:project) }

        subject(:response) do
          described_class.new(
            service_account: service_account,
            organization: organization,
            container: project
          ).execute
        end

        it 'scopes the audit event to the container' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'autonomous_oauth_token_created',
              scope: project,
              target: service_account
            )
          )

          response
        end
      end
    end

    context 'when service account is nil' do
      let(:service_account) { nil }

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to eq('A valid service account is required for autonomous workflow execution')
      end
    end

    context 'when user is not a service account' do
      let(:service_account) { create(:user) }

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to eq('A valid service account is required for autonomous workflow execution')
      end
    end

    context 'when service account belongs to a different organization' do
      let_it_be(:other_organization) { create(:organization) }

      before do
        service_account.update!(organization_id: other_organization.id)
      end

      after do
        service_account.update!(organization_id: organization.id)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to eq('Service account must belong to the same organization as the project')
      end
    end

    context 'when oauth application is not configured' do
      before do
        ::Ai::Setting.for_organization(organization).update!(duo_workflow_oauth_application_id: nil)
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to eq('OAuth application must be configured for autonomous workflow execution')
      end
    end

    context 'when token creation fails' do
      before do
        ::Ai::Setting.for_organization(organization).update!(duo_workflow_oauth_application_id: oauth_app.id)
        allow(OauthAccessToken).to receive(:create!).and_raise(
          ActiveRecord::RecordInvalid.new(OauthAccessToken.new)
        )
      end

      it 'returns an error' do
        expect(response).to be_error
        expect(response.message).to include('Failed to generate autonomous oauth token')
      end
    end
  end
end
