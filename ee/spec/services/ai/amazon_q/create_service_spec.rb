# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::CreateService, feature_category: :ai_agents do
  describe '#execute', :enable_admin_mode do
    let_it_be(:organization) { create(:common_organization) }
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
    let_it_be(:user) { create(:admin, organizations: [organization]) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }
    let_it_be(:base_params) do
      { role_arn: 'a', availability: 'default_on', auto_review_enabled: true, organization_id: organization.id }
    end

    let(:params) { base_params }
    let(:status) { 200 }
    let(:body) { 'success' }

    before do
      stub_current_organization(organization)
      allow(License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application")
        .and_return(status: status, body: body)
      ::Gitlab::CurrentSettings.current_application_settings.update!(duo_availability: 'default_off')
    end

    subject(:instance) { described_class.new(user, params) }

    context 'with missing role_arn param' do
      let(:params) { base_params.except(:role_arn) }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing role_arn parameter'
        )
      end
    end

    context 'with missing availability param' do
      let(:params) { base_params.except(:availability) }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing availability parameter'
        )
      end
    end

    context 'with invalid availability param' do
      let(:params) { base_params.merge(availability: 'a') }

      it 'does not change duo_availability' do
        expect { instance.execute }
          .not_to change { ::Gitlab::CurrentSettings.current_application_settings.duo_availability }
      end

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: "availability must be one of: default_on, default_off, never_on"
        )
      end
    end

    context 'when setting availability to never_on' do
      let(:params) { base_params.merge(availability: 'never_on') }

      it 'blocks service account' do
        instance.execute

        service_account = Ai::Setting.for_organization(organization).amazon_q_service_account_user

        expect(service_account.blocked?).to be true
      end
    end

    context 'with missing organization_id param' do
      let(:params) { base_params.except(:organization_id) }

      it 'returns ServiceResponse.error with expected error message' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Missing organization_id parameter'
        )
      end
    end

    it 'updates application settings' do
      expect { instance.execute }
        .to change { Ai::Setting.for_organization(organization).amazon_q_role_arn }.from(nil).to('a')
        .and change {
          ::Gitlab::CurrentSettings.current_application_settings.duo_availability
        }.from(:default_off).to(:default_on)
    end

    it 'creates an audit event' do
      instance.execute

      service_account = Ai::Setting.for_organization(organization).amazon_q_service_account_user
      oauth_application = Ai::Setting.for_organization(organization).amazon_q_oauth_application

      expect(AuditEventReader.last.details).to include(
        event_name: 'q_onbarding_updated',
        custom_message: "Changed availability to default_on, " \
          "amazon_q_role_arn to a, " \
          "amazon_q_service_account_user_id to #{service_account.id}, " \
          "amazon_q_oauth_application_id to #{oauth_application.id}, " \
          "amazon_q_ready to true"
      )
    end

    it 'creates amazon q instance integration' do
      allow(PropagateIntegrationWorker).to receive(:perform_async)

      expect { instance.execute }.to change { Integrations::AmazonQ.count }.by(1)

      integration = Integrations::AmazonQ.last

      expect(integration).to be_active
      expect(integration.role_arn).to eq('a')
      expect(integration.availability).to eq("default_on")
      expect(integration.auto_review_enabled).to be(true)
      expect(integration.merge_requests_events).to be(true)
      expect(integration.pipeline_events).to be(true)
      expect(PropagateIntegrationWorker).to have_received(:perform_async).with(integration.id)
    end

    it 'returns an error if amazon q instance integration is not saved' do
      expect(PropagateIntegrationWorker).not_to receive(:perform_async)
      expect_next_instance_of(Integrations::AmazonQ) do |instance|
        expect(instance).to receive(:update).and_return(false)
        instance.errors.add(:base, 'Integration error')
      end

      expect(instance.execute).to have_attributes(
        success?: false,
        message: 'Failed to create an integration: Error Integration error'
      )
      expect(Integrations::AmazonQ.count).to eq(0)
    end

    it 'returns an error if amazon q instance integration cannot be found' do
      stub_licensed_features(amazon_q: false)

      expect(instance.execute).to have_attributes(
        success?: false,
        message: 'Failed to create an integration: Amazon Q is not available'
      )
      expect(Integrations::AmazonQ.count).to eq(0)
    end

    it 'returns ServiceResponse.success' do
      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end

    context 'when q service account does not already exist' do
      it 'creates q service account with composite identity stores the user id in application settings' do
        expect(Ai::Setting.for_organization(organization).amazon_q_service_account_user).to be_falsey

        instance.execute

        service_account_user = Ai::Setting.for_organization(organization).amazon_q_service_account_user
        expect(service_account_user).to be_truthy
        expect(service_account_user.composite_identity_enforced?).to be true
        expect(service_account_user.private_profile?).to be true
      end

      context 'when there is no user with the username amazon-q' do
        it 'sets the username as amazon-q' do
          instance.execute

          service_account_user = Ai::Setting.for_organization(organization).amazon_q_service_account_user
          expect(service_account_user.username).to eq 'amazon-q'
        end
      end

      context 'when there us a user with the username amazon-q' do
        before do
          create(:user, username: 'amazon-q')
        end

        it 'add a dash and integer to the username' do
          instance.execute

          service_account_user = Ai::Setting.for_organization(organization).amazon_q_service_account_user
          expect(service_account_user.username).to eq 'amazon-q-1'
        end
      end
    end

    context 'when q service account already exists' do
      let_it_be(:service_account) { create(:service_account) }

      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account.id)
        allow(::Users::ServiceAccounts::CreateService).to receive(:new)
      end

      it 'does not attempt to create q service account' do
        expect { instance.execute }.not_to change { Ai::Setting.for_organization(organization).amazon_q_service_account_user_id }
        expect(::Users::ServiceAccounts::CreateService).not_to have_received(:new)
      end
    end

    context 'when an existing oauth application does not exist' do
      it 'creates a new oauth application' do
        expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |client|
          expect(client).to receive(:perform_create_auth_application)
            .with(
              doorkeeper_application,
              doorkeeper_application.secret,
              params[:role_arn]
            ).and_call_original
        end

        expect(Authn::OauthApplication).to receive(:new).with(
          {
            name: 'Amazon Q OAuth',
            redirect_uri: Gitlab::Routing.url_helpers.root_url,
            scopes: [:api, :read_repository, :write_repository, :"user:*"],
            trusted: false,
            confidential: false,
            organization_id: organization.id
          }
        ).and_return(doorkeeper_application)

        expect { instance.execute }.to change { Ai::Setting.for_organization(organization).amazon_q_oauth_application_id }
          .from(nil).to(doorkeeper_application.id)
      end

      context 'when AI client returns a 403 error' do
        let(:status) { 403 }
        let(:body) { '403 Unauthorized' }

        it 'displays a 403 error in the errors' do
          expect(instance.execute).to have_attributes(
            success?: false,
            message: 'Application could not be created by the AI Gateway: Error 403 - 403 Unauthorized'
          )
        end
      end
    end

    context 'when an oauth application exists' do
      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_oauth_application_id: doorkeeper_application.id)
      end

      it 'does not create a new oauth application' do
        expect(Authn::OauthApplication).not_to receive(:new)

        expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |client|
          expect(client).to receive(:perform_create_auth_application)
            .with(
              doorkeeper_application,
              doorkeeper_application.secret,
              params[:role_arn]
            ).and_call_original
        end

        result = nil
        expect do
          result = instance.execute
        end.not_to change {
          Ai::Setting.for_organization(organization).amazon_q_oauth_application_id
        }

        expect(result.success?).to be_truthy
      end
    end
  end
end
