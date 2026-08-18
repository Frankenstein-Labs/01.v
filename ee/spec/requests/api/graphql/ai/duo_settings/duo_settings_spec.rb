# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab Duo settings.', feature_category: :'self-hosted_models' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be_with_refind(:duo_settings) { create(:ai_settings, organization: current_user.organization) }

  let(:query) do
    %(
      query getDuoSettings {
        duoSettings {
          aiGatewayUrl
          aiGatewayTimeoutSeconds
          duoAgentPlatformServiceUrl
          duoCoreFeaturesEnabled
        }
      }
    )
  end

  let(:duo_settings_data) { graphql_data_at(:duoSettings) }

  before do
    stub_application_setting(
      ai_gateway_url: 'http://0.0.0.0:5052',
      ai_gateway_timeout_seconds: 120,
      duo_agent_platform_service_url: 'grpc://dap.example.com:50052'
    )
  end

  context 'when the user is not authorized' do
    context 'for Duo self-hosted settings' do
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      before do
        stub_licensed_features(self_hosted_models: false)
      end

      it 'returns nil for the Duo self-hosted setting' do
        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'aiGatewayUrl' => nil,
            'aiGatewayTimeoutSeconds' => 120,
            'duoAgentPlatformServiceUrl' => nil,
            'duoCoreFeaturesEnabled' => false
          }
        )
      end
    end

    context 'for Duo Core features' do
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
      end

      before do
        stub_licensed_features(code_suggestions: false, ai_chat: false)
      end

      it 'returns nil for the Duo Core features setting' do
        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'aiGatewayUrl' => 'http://0.0.0.0:5052',
            'aiGatewayTimeoutSeconds' => 120,
            'duoAgentPlatformServiceUrl' => 'grpc://dap.example.com:50052',
            'duoCoreFeaturesEnabled' => nil
          }
        )
      end

      it 'returns nil for minimum access level settings' do
        duo_settings.update!(
          minimum_access_level_execute: ::Gitlab::Access::DEVELOPER,
          minimum_access_level_execute_async: ::Gitlab::Access::DEVELOPER,
          minimum_access_level_manage: ::Gitlab::Access::DEVELOPER,
          minimum_access_level_enable_on_projects: ::Gitlab::Access::DEVELOPER
        )

        query = %(
          query getDuoSettings {
            duoSettings {
              minimumAccessLevelExecute
              minimumAccessLevelExecuteAsync
              minimumAccessLevelManage
              minimumAccessLevelEnableOnProjects
            }
          }
        )

        post_graphql(query, current_user: current_user)

        expect(duo_settings_data).to eq(
          {
            'minimumAccessLevelExecute' => nil,
            'minimumAccessLevelExecuteAsync' => nil,
            'minimumAccessLevelManage' => nil,
            'minimumAccessLevelEnableOnProjects' => nil
          }
        )
      end
    end
  end

  context 'when user is authorized for everything' do
    let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

    it 'returns the expected response' do
      post_graphql(query, current_user: current_user)

      expect(duo_settings_data).to eq(
        {
          'aiGatewayUrl' => 'http://0.0.0.0:5052',
          'aiGatewayTimeoutSeconds' => 120,
          'duoAgentPlatformServiceUrl' => 'grpc://dap.example.com:50052',
          'duoCoreFeaturesEnabled' => false
        }
      )
    end

    it 'returns minimum access level settings' do
      duo_settings.update!(
        minimum_access_level_execute: ::Gitlab::Access::DEVELOPER,
        minimum_access_level_execute_async: ::Gitlab::Access::DEVELOPER,
        minimum_access_level_manage: ::Gitlab::Access::DEVELOPER,
        minimum_access_level_enable_on_projects: ::Gitlab::Access::DEVELOPER
      )

      query = %(
          query getDuoSettings {
            duoSettings {
              minimumAccessLevelExecute
              minimumAccessLevelExecuteAsync
              minimumAccessLevelManage
              minimumAccessLevelEnableOnProjects
            }
          }
        )

      post_graphql(query, current_user: current_user)

      expect(duo_settings_data).to eq(
        {
          'minimumAccessLevelExecute' => 'DEVELOPER',
          'minimumAccessLevelExecuteAsync' => 'DEVELOPER',
          'minimumAccessLevelManage' => 'DEVELOPER',
          'minimumAccessLevelEnableOnProjects' => 'DEVELOPER'
        }
      )
    end
  end

  context 'when the user is not authorized for anything' do
    it 'returns nil for the unauthorized settings' do
      post_graphql(query, current_user: current_user)

      expect(duo_settings_data).to eq(
        {
          'aiGatewayUrl' => nil,
          'aiGatewayTimeoutSeconds' => 120,
          'duoAgentPlatformServiceUrl' => nil,
          'duoCoreFeaturesEnabled' => nil
        }
      )
    end
  end
end
