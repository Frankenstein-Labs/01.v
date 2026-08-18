# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateOauthAccessTokenService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:user) { create(:user, organizations: [organization]) }

    subject(:execute) do
      described_class.new(current_user: user, organization: organization).execute
    end

    before do
      stub_saas_features(duo_workflow: true)
    end

    context 'when the duo workflow oauth application already exists' do
      let_it_be(:oauth_application) do
        create(
          :oauth_application,
          owner: nil,
          id: application_settings.duo_workflow_oauth_application_id,
          scopes: [:ai_workflows, :mcp, :ai_features]
        )
      end

      before do
        stub_application_setting({ duo_workflow_oauth_application_id: oauth_application.id })
      end

      context 'when the user does not have a valid oauth access token' do
        shared_examples 'creates a new oauth access token for the duo workflow oauth app' do
          it 'creates a new oauth access token for the duo workflow oauth app' do
            expect(oauth_application).not_to receive(:update!)
            expect(::OauthAccessToken.sticking).to receive(:stick)

            expect { execute }.to change { OauthAccessToken.count }.by(1)
            token = execute[:oauth_access_token]
            expect(token.resource_owner_id).to eq user.id
            expect(token.application).to eq oauth_application
            expect(token.scopes).to contain_exactly('mcp', 'ai_workflows', 'ai_features')
            expect(oauth_application.reload.scopes).to contain_exactly('mcp', 'ai_workflows', 'ai_features')
          end
        end

        context 'when oauth token has expired' do
          before do
            create_expired_token
          end

          it_behaves_like 'creates a new oauth access token for the duo workflow oauth app'
        end

        context 'when oauth token is not present' do
          it_behaves_like 'creates a new oauth access token for the duo workflow oauth app'
        end
      end

      context 'when the user already has an oauth access token' do
        it 'creates a new oauth access token' do
          described_class.new(current_user: user, organization: organization).execute

          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end

      context 'when the application is missing mcp scope' do
        let_it_be(:oauth_application) do
          create(
            :oauth_application, owner: nil, scopes: [:ai_workflows],
            id: application_settings.duo_workflow_oauth_application_id
          )
        end

        it 'updates the scopes to contain it' do
          expect { execute }.to change { OauthAccessToken.count }.by(1)
          token = execute[:oauth_access_token]
          expect(token.resource_owner_id).to eq user.id
          expect(token.application).to eq oauth_application
          expect(token.scopes).to contain_exactly('mcp', 'ai_workflows')
          expect(oauth_application.reload.scopes).to contain_exactly('mcp', 'ai_workflows')
        end
      end
    end

    context 'when workflow_definition exists' do
      subject(:execute) do
        described_class.new(current_user: user, organization: organization, workflow_definition: workflow_definition)
          .execute
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'creates token' do
          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'creates token when duo_workflow feature flag is enabled' do
          expect { execute }.to change { OauthAccessToken.count }.by(1)
        end
      end
    end

    shared_examples 'creates a new doorkeeper oauth application' do
      it 'creates a new doorkeeper oauth application' do
        expect(::Gitlab::CurrentSettings).to receive(:expire_current_application_settings).and_call_original
        expect { execute }.to change { Authn::OauthApplication.count }.by(1)

        application = Authn::OauthApplication.last

        expect(application_settings.duo_workflow_oauth_application_id).to eq(application.id)
        expect(application.scopes).to contain_exactly('mcp', 'ai_workflows')
      end
    end

    context 'when the duo workflow oauth application does not already exists' do
      it_behaves_like 'creates a new doorkeeper oauth application'
    end

    context 'when the duo workflow oauth application is deleted' do
      before do
        application_settings.update!(duo_workflow_oauth_application_id: non_existing_record_id)
      end

      it_behaves_like 'creates a new doorkeeper oauth application'
    end

    def application_settings
      ::Gitlab::CurrentSettings.current_application_settings
    end

    def create_expired_token
      OauthAccessToken.create!(
        application_id: oauth_application.id,
        expires_in: -2.seconds,
        resource_owner_id: user.id,
        token: Doorkeeper::OAuth::Helpers::UniqueToken.generate,
        organization: organization,
        scopes: oauth_application.scopes.to_s
      )
    end
  end
end
