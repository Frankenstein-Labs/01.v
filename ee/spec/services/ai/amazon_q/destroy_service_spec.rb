# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::DestroyService, feature_category: :ai_agents do
  let_it_be(:organization) { create(:common_organization) }

  before do
    stub_current_organization(organization)
  end

  describe '#execute' do
    let_it_be(:user) { create(:admin) }
    let_it_be(:service_account) { create(:service_account) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }
    let_it_be(:role_arn) { SecureRandom.hex }
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }

    let(:params) { { role_arn: 'a' } }
    let(:status) { 204 }
    let(:body) { nil }

    before do
      stub_request(:post, "#{Gitlab::AiGateway.url}/v1/amazon_q/oauth/application/delete")
        .and_return(status: status, body: body)

      stub_licensed_features(amazon_q: true)

      Ai::Setting.for_organization(organization).update!(
        amazon_q_service_account_user_id: service_account.id,
        amazon_q_oauth_application_id: doorkeeper_application.id,
        amazon_q_ready: true,
        amazon_q_role_arn: role_arn
      )
    end

    subject(:instance) { described_class.new(user) }

    it 'returns ServiceResponse.success' do
      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end

    context 'when the AI settings update fails' do
      it 'returns ServiceResponse.error with expected error message' do
        ai_settings = Ai::Setting.for_organization(organization)
        allow(Ai::Setting).to receive(:for_organization).and_return(ai_settings)
        allow(ai_settings).to receive(:update).and_return(false)
        allow(ai_settings).to receive_message_chain(
          :errors, :full_messages, :to_sentence
        ).and_return('Oh oh!')

        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Oh oh!'
        )
      end
    end

    context 'when the AI client returns an error' do
      let(:status) { 403 }
      let(:body) { '403 Unauthorized' }

      it 'responds with AI Gateway error' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Application could not be deleted by the AI Gateway: Error 403 - 403 Unauthorized'
        )
      end
    end

    context 'when the AI client returns UUID mismatch error' do
      let(:status) { 401 }
      let(:body) { '{"error":"Header mismatch \'X-Gitlab-Instance-Id\'"}' }

      it 'responds with UUID mismatch error' do
        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Uuid mismatch GitLab instance UUID does not match the registered Identity Provider UUID in AWS'
        )
      end
    end

    it 'blocks the service account' do
      expect { instance.execute }.to change { service_account.reload.blocked? }.from(false).to(true)
    end

    it 'destroys the oauth application' do
      instance.execute

      expect { doorkeeper_application.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'succeeds when application is already deleted' do
      doorkeeper_application.destroy!

      expect(instance.execute.success?).to be(true)
    end

    it 'updates application settings' do
      expect { instance.execute }
        .to change {
          Ai::Setting.for_organization(organization).amazon_q_oauth_application_id
        }.from(doorkeeper_application.id).to(nil).and change {
          Ai::Setting.for_organization(organization).amazon_q_ready
        }.from(true).to(false).and change {
          Ai::Setting.for_organization(organization).amazon_q_role_arn
        }.from(role_arn).to(nil).and not_change {
          Ai::Setting.for_organization(organization).amazon_q_service_account_user_id
        }
    end

    it 'creates an audit event' do
      expect { instance.execute }.to change { AuditEventReader.count }.by(1)
      expect(AuditEventReader.last.details).to include(
        event_name: 'q_onbarding_updated',
        custom_message: 'Changed amazon_q_role_arn to null, ' \
          'amazon_q_oauth_application_id to null, ' \
          'amazon_q_ready to null'
      )
    end

    it 'destroys the instance integration' do
      integration = create(:amazon_q_integration)
      project_integration = create(:amazon_q_integration, instance: false, project: create(:project),
        inherit_from_id: integration.id)
      group_integration = create(:amazon_q_integration, instance: false, group: create(:group),
        inherit_from_id: integration.id)

      expect { instance.execute }.to change { Integrations::AmazonQ.count }.from(3).to(0)
      expect { integration.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { project_integration.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { group_integration.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'returns an error if amazon q instance integration is not deleted' do
      integration = create(:amazon_q_integration)

      expect(Integrations::AmazonQ).to receive(:for_instance).and_return([integration])
      expect(integration).to receive(:destroy).and_return(false)
      integration.errors.add(:base, 'Integration error')

      expect(instance.execute).to have_attributes(
        success?: false,
        message: 'Failed to delete an integration: Error Integration error'
      )
      expect(Integrations::AmazonQ.count).to eq(1)
    end
  end
end
