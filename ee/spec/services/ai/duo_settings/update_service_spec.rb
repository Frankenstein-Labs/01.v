# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::UpdateService, feature_category: :"self-hosted_models" do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:user) { create(:admin) }

  let(:application_settings) { ::Gitlab::CurrentSettings.current_application_settings }
  let(:duo_settings) { ::Ai::Setting.for_organization(organization) }

  let(:params) do
    { ai_gateway_url: "http://new-ai-gateway-url", duo_core_features_enabled: true, ai_gateway_timeout_seconds: 100 }
  end

  subject(:service_result) { described_class.new(params, current_user: user).execute }

  before do
    # So the caching behaves like it would in production
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    application_settings

    stub_current_organization(organization)
  end

  describe '#execute', :enable_admin_mode do
    context 'when user is not an admin' do
      let_it_be(:user) { create(:user) }

      it 'returns an error without updating settings' do
        expect { service_result }.to not_change { duo_settings.reload.duo_core_features_enabled }
          .and not_change { application_settings.reload.ai_gateway_url }

        expect(service_result).to be_error
        expect(service_result.message).to eq("Unable to update AI settings")
      end
    end

    context 'when update succeeds' do
      it 'routes instance-level params to ApplicationSetting and organization params to Ai::Setting' do
        application_settings.update!(self_hosted_duo_agent_platform_service_secure: false)

        params.merge!(
          duo_agent_platform_service_url: 'grpc://dap.example.com:50052',
          self_hosted_duo_agent_platform_service_secure: true,
          amazon_q_role_arn: 'arn:aws:iam::123456789012:role/q'
        )

        expect { service_result }.to change { application_settings.reload.ai_gateway_url }
          .to("http://new-ai-gateway-url")
          .and change { application_settings.reload.ai_gateway_timeout_seconds }.to(100)
          .and change { application_settings.reload.duo_agent_platform_service_url }.to('grpc://dap.example.com:50052')
          .and change { application_settings.reload.self_hosted_duo_agent_platform_service_secure }.to(true)
          .and change { duo_settings.reload.duo_core_features_enabled }.to(true)
          .and change { duo_settings.reload.amazon_q_role_arn }.to('arn:aws:iam::123456789012:role/q')

        expect(service_result).to be_success
        expect(service_result.payload).to eq(duo_settings)
      end

      it 'audits both the organization-scoped and instance-level settings changes' do
        ai_auditor = instance_double(Ai::DuoSettings::ChangesAuditor)
        instance_auditor = instance_double(Ai::DuoSettings::ChangesAuditor)
        allow(Ai::DuoSettings::ChangesAuditor).to receive(:new)
          .with(user, an_instance_of(::Ai::Setting)).and_return(ai_auditor)
        allow(Ai::DuoSettings::ChangesAuditor).to receive(:new)
          .with(user, an_instance_of(::ApplicationSetting)).and_return(instance_auditor)

        expect(ai_auditor).to receive(:execute)
        expect(instance_auditor).to receive(:execute)

        service_result
      end

      context 'with only organization-scoped params' do
        let(:params) { { duo_core_features_enabled: true } }

        it 'does not audit the instance-level settings' do
          ai_auditor = instance_double(Ai::DuoSettings::ChangesAuditor, execute: true)
          allow(Ai::DuoSettings::ChangesAuditor).to receive(:new)
            .with(user, an_instance_of(::Ai::Setting)).and_return(ai_auditor)

          expect(Ai::DuoSettings::ChangesAuditor).not_to receive(:new)
            .with(user, an_instance_of(::ApplicationSetting))

          expect(service_result).to be_success
        end
      end
    end

    context 'when update fails due to a validation error' do
      let(:params) { { ai_gateway_url: 'invalid-url', duo_core_features_enabled: true } }

      it 'returns an error response with validation messages' do
        expect { service_result }.to not_change { duo_settings.reload.duo_core_features_enabled }
          .and not_change { application_settings.reload.ai_gateway_url }

        expect(service_result).to be_error
        expect(service_result.errors).to match_array(
          ["Ai gateway url Only allowed schemes are http, https"]
        )
      end

      it 'does not call the changes auditor' do
        expect(Ai::DuoSettings::ChangesAuditor).not_to receive(:new)

        service_result
      end
    end

    context 'when update fails due to an unexpected error' do
      let(:error) { StandardError.new("something unexpected") }

      before do
        allow(::Ai::Setting).to receive(:for_organization).and_raise(error)
      end

      it 'returns a generic error response without leaking details' do
        expect(service_result).to be_error
        expect(service_result.message).to eq("Unable to update AI settings")
      end

      it 'tracks the exception in Sentry' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)

        service_result
      end
    end
  end
end
