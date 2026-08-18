# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::OnboardingService, type: :service, feature_category: :duo_agent_platform do
  describe '#execute', :enable_admin_mode do
    let_it_be(:organization) { create(:common_organization) }
    let_it_be(:user) { create(:admin, organizations: [organization]) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }

    before do
      allow(License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
    end

    subject(:instance) { described_class.new(current_user: user, organization: organization) }

    context 'when duo workflow service account does not already exist' do
      it 'creates service account with composite identity stores the user id in ai settings' do
        expect(Ai::Setting.for_organization(organization).duo_workflow_service_account_user_id).to be_falsey

        instance.execute

        service_account_user_id = Ai::Setting.for_organization(organization).duo_workflow_service_account_user_id
        expect(service_account_user_id).to be_truthy

        service_account_user = User.find_by_id(service_account_user_id)
        expect(service_account_user.composite_identity_enforced?).to be true
        expect(service_account_user.private_profile?).to be true
        expect(service_account_user.name).to eq('Duo Developer')
        expect(service_account_user.username).to eq('duo-developer')
      end
    end

    context 'when duo workflow service account already exists' do
      let_it_be(:service_account) { create(:service_account) }

      before do
        Ai::Setting.for_organization(organization).update!(duo_workflow_service_account_user_id: service_account.id)
        allow(::Users::ServiceAccounts::CreateService).to receive(:new)
      end

      it 'does not attempt to create a service account' do
        expect { instance.execute }.not_to change { Ai::Setting.for_organization(organization).duo_workflow_service_account_user_id }
        expect(::Users::ServiceAccounts::CreateService).not_to have_received(:new)
      end
    end

    context 'when an existing oauth application does not exist' do
      it 'creates a new oauth application' do
        expect(Ai::Setting.for_organization(organization).duo_workflow_oauth_application_id).to be_nil

        expect(Authn::OauthApplication).to receive(:new).with(
          {
            name: 'GitLab Duo Agent Platform Composite OAuth Application',
            redirect_uri: Gitlab::Routing.url_helpers.root_url,
            scopes: [:ai_workflows, :mcp, :"user:*"],
            trusted: true,
            confidential: true,
            organization: organization
          }
        ).and_return(doorkeeper_application)

        instance.execute

        expect(Ai::Setting.for_organization(organization).duo_workflow_oauth_application_id)
          .to eq(doorkeeper_application.id)
      end
    end

    context 'when an oauth application exists' do
      before do
        Ai::Setting.for_organization(organization).update!(duo_workflow_oauth_application_id: doorkeeper_application.id)
      end

      it 'does not create a new oauth application' do
        expect { instance.execute }.not_to change {
          Ai::Setting.for_organization(organization).duo_workflow_oauth_application_id
        }
        expect(Authn::OauthApplication).not_to receive(:new)
      end
    end
  end

  describe '#ai_settings' do
    let_it_be(:organization) { create(:organization) }
    let(:setting) { build(:ai_settings) }
    let_it_be(:user) { create(:user, organizations: [organization]) }

    subject(:service) { described_class.new(current_user: user, organization: organization) }

    it 'reads the settings for the organization' do
      expect(Ai::Setting).to receive(:for_organization).with(organization).and_return(setting)

      expect(service.send(:ai_settings)).to eq(setting)
    end
  end
end
