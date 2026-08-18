# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating an AI Feature setting', feature_category: :"self-hosted_models" do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:current_user) { create(:admin) }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be_with_reload(:add_on_purchase) do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active, :self_managed)
  end

  let!(:duo_settings) do
    create(
      :ai_settings,
      organization: current_user.organization,
      duo_core_features_enabled: false
    )
  end

  let(:application_settings) { ::Gitlab::CurrentSettings.current_application_settings }

  let(:mutation_name) { :duo_settings_update }
  let(:mutation_params) do
    {
      ai_gateway_url: "http://new-ai-gateway-url",
      duo_core_features_enabled: true,
      duo_agent_platform_service_url: "new-duo-agent-platform-url:50052",
      self_hosted_duo_agent_platform_service_secure: true,
      ai_gateway_timeout_seconds: 100
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    application_settings.update!(
      ai_gateway_url: 'http://0.0.0.0:5052',
      duo_agent_platform_service_url: '0.0.0.0:50052',
      self_hosted_duo_agent_platform_service_secure: false
    )
  end

  describe '#resolve', :enable_admin_mode do
    shared_examples 'performs the right authorization for duo_core_features_enabled' do
      it 'performs the right authorization for duo_core_features_enabled correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(current_user, :update_duo_core_setting)

        request
      end
    end

    shared_examples 'performs the right authorization for ai_gateway_timeout_seconds' do
      it 'performs the right authorization for ai_gateway_timeout_seconds correctly' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?).with(current_user, :update_ai_gateway_timeout)

        request
      end
    end

    context 'when the user is not an admin' do
      let(:current_user) { create(:user) }
      let(:mutation_params) { {} }

      it 'returns an error' do
        request

        expect(graphql_errors).to be_present
        expect(graphql_errors.pluck('message')).to match_array(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end

    context 'when the user does not have write access' do
      context 'when attempting to update ai_gateway_url' do
        let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

        before do
          stub_licensed_features(self_hosted_models: false)
        end

        it_behaves_like 'performs the right authorization'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting ai_gateway_url."
          )
        end
      end

      context 'when attempting to update duo_agent_platform_service_url' do
        let(:mutation_params) { { duo_agent_platform_service_url: "new-duo-agent-platform-url:50052" } }

        before do
          stub_licensed_features(self_hosted_models: false)
        end

        it_behaves_like 'performs the right authorization'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting duo_agent_platform_service_url."
          )
        end
      end

      context 'when attempting to update ai_gateway_timeout_seconds' do
        let(:mutation_params) { { ai_gateway_timeout_seconds: 100 } }

        before do
          stub_licensed_features(self_hosted_models: false, code_suggestions: false, ai_chat: false)
        end

        it_behaves_like 'performs the right authorization for ai_gateway_timeout_seconds'

        it 'returns an error about the missing permission' do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(current_user, :update_ai_gateway_timeout).and_return(false)

          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting ai_gateway_timeout_seconds."
          )
        end
      end

      context 'when attempting to update self_hosted_duo_agent_platform_service_secure' do
        let(:mutation_params) { { self_hosted_duo_agent_platform_service_secure: true } }

        before do
          stub_licensed_features(self_hosted_models: false)
        end

        it_behaves_like 'performs the right authorization'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting self_hosted_duo_agent_platform_service_secure."
          )
        end
      end

      context 'when attempting to update duo_core_features_enabled' do
        let(:mutation_params) { { duo_core_features_enabled: true } }

        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        it_behaves_like 'performs the right authorization for duo_core_features_enabled'

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting duo_core_features_enabled."
          )
        end
      end

      context 'when attempting to update duo_cli_enabled' do
        let(:mutation_params) { { duo_cli_enabled: false } }

        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        it 'returns an error about the missing permission' do
          request

          expect(graphql_errors).to be_present
          expect(graphql_errors.pluck('message')).to match_array(
            "You don't have permission to update the setting duo_cli_enabled."
          )
        end

        it 'does not update the database value' do
          expect { request }.not_to change { duo_settings.reload.duo_cli_enabled }
        end
      end

      context 'when attempting to update ai minimum access level settings' do
        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        where(:permission) do
          %i[
            minimum_access_level_execute
            minimum_access_level_execute_async
            minimum_access_level_manage
            minimum_access_level_enable_on_projects
          ]
        end

        with_them do
          let(:mutation_params) { { permission => 'DEVELOPER' } }

          it 'returns an error about the missing permission' do
            request

            expect(duo_settings.reload.public_send(permission)).to be_nil
            expect(graphql_errors).to be_present
            expect(graphql_errors.pluck('message')).to match_array(
              "You don't have permission to update the setting #{permission}."
            )
          end
        end
      end

      context 'when attempting to update network access boolean settings' do
        before do
          stub_licensed_features(code_suggestions: false, ai_chat: false)
        end

        where(:setting) do
          %i[
            include_recommended_allowed
            allow_all_unix_sockets
            allow_project_extension
          ]
        end

        with_them do
          let(:mutation_params) { { setting => true } }

          it 'returns an error about the missing permission' do
            request

            expect(graphql_errors).to be_present
            expect(graphql_errors.pluck('message')).to match_array(
              "You don't have permission to update the setting #{setting}."
            )
          end
        end
      end
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'
      it_behaves_like 'performs the right authorization for duo_core_features_enabled'

      context 'when on a Dedicated instance without self_hosted_models license' do
        let(:mutation_params) { { ai_gateway_timeout_seconds: 100 } }

        before do
          stub_licensed_features(self_hosted_models: false, code_suggestions: true, ai_chat: true)
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        end

        it 'allows updating ai_gateway_timeout_seconds' do
          request

          expect(graphql_errors).to be_nil
          result = json_response['data']['duoSettingsUpdate']
          expect(result['errors']).to eq([])
          expect(result['duoSettings']).to include('aiGatewayTimeoutSeconds' => 100)
        end
      end

      context 'when there are errors' do
        context 'when there is an error for ai_gateway_url' do
          let(:mutation_params) { { ai_gateway_url: "foobar" } }

          it 'returns an error' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['errors']).to match_array(
              ["Ai gateway url Only allowed schemes are http, https"]
            )

            expect { duo_settings.reload }.not_to change { duo_settings }
          end

          it 'returns the existing ai setting values' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => 'http://0.0.0.0:5052',
              'duoCoreFeaturesEnabled' => false
            )
          end

          it 'does not create ai settings when the update service returns an error' do
            duo_settings.destroy!
            allow_next_instance_of(::Ai::DuoSettings::UpdateService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Update failed'))
            end

            expect { request }.not_to change { ::Ai::Setting.count }
          end
        end

        context 'when there is an error for duoCoreFeaturesEnabled' do
          let(:mutation_params) { { duoCoreFeaturesEnabled: nil } }

          it 'returns an error' do
            request

            result = json_response

            expect(result['data']['duoSettingsUpdate']).to be_nil
            expect(result['errors'].count).to eq(1)
            expect(result['errors'].first['message']).to eq("duoCoreFeaturesEnabled can't be null")

            expect { duo_settings.reload }.not_to change { duo_settings }
          end
        end
      end

      context 'when there are no errors' do
        it 'updates Duo settings' do
          request

          result = json_response['data']['duoSettingsUpdate']

          expect(result['duoSettings']).to include(
            "aiGatewayUrl" => "http://new-ai-gateway-url",
            "duoCoreFeaturesEnabled" => true,
            "aiGatewayTimeoutSeconds" => 100,
            "selfHostedDuoAgentPlatformServiceSecure" => true
          )
          expect(result['errors']).to eq([])

          expect { duo_settings.reload }.to change { duo_settings.duo_core_features_enabled }.to(true)

          expect(application_settings.reload).to have_attributes(
            ai_gateway_url: "http://new-ai-gateway-url",
            duo_agent_platform_service_url: "new-duo-agent-platform-url:50052",
            self_hosted_duo_agent_platform_service_secure: true,
            ai_gateway_timeout_seconds: 100
          )
        end

        context 'when ai_gateway_url arg is a blank string' do
          let(:mutation_params) { { ai_gateway_url: "" } }

          it 'coerces it to nil' do # an empty string will cause the Duo healthcheck to error
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("aiGatewayUrl" => nil)
            expect(result['errors']).to eq([])

            expect(application_settings.reload.ai_gateway_url).to be_nil
          end
        end

        context 'when ai_gateway_url has a trailing /' do
          let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url/" } }

          it 'remove the trailing slash before saving' do # an empty string will cause the Duo healthcheck to error
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("aiGatewayUrl" => "http://new-ai-gateway-url")
            expect(result['errors']).to eq([])

            expect(application_settings.reload.ai_gateway_url).to eq("http://new-ai-gateway-url")
          end
        end

        context 'when duo_agent_platform_service_url arg is a blank string' do
          let(:mutation_params) { { duo_agent_platform_service_url: "" } }

          it 'coerces it to nil' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("duoAgentPlatformServiceUrl" => nil)
            expect(result['errors']).to eq([])

            expect(application_settings.reload.duo_agent_platform_service_url).to be_nil
          end
        end

        context 'when duo_agent_platform_service_url has a trailing /' do
          let(:mutation_params) { { duo_agent_platform_service_url: "new-duo-agent-platform-url:50052/" } }

          it 'remove the trailing slash before saving' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include("duoAgentPlatformServiceUrl" => "new-duo-agent-platform-url:50052")
            expect(result['errors']).to eq([])

            expect(application_settings.reload.duo_agent_platform_service_url)
              .to eq("new-duo-agent-platform-url:50052")
          end
        end

        context 'when the user has no read permission for ai_gateway_url' do
          let(:mutation_params) { { duo_core_features_enabled: true } }

          before do
            stub_licensed_features(self_hosted_models: false)
          end

          it 'updates the duo_core_features_enabled setting and returns nil for ai_gateway_url' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => nil,
              'duoCoreFeaturesEnabled' => true
            )
            expect(result['errors']).to eq([])

            expect { duo_settings.reload }.to change { duo_settings.duo_core_features_enabled }.to(true)

            expect(application_settings.reload.ai_gateway_url).to eq('http://0.0.0.0:5052')
          end
        end

        context 'when the user has no read permission for duo_core_features_enabled' do
          let(:mutation_params) { { ai_gateway_url: "http://new-ai-gateway-url" } }

          before do
            stub_licensed_features(code_suggestions: false, ai_chat: false)
          end

          it 'updates the ai_gateway_url setting and returns nil for duo_core_features_enabled' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'aiGatewayUrl' => 'http://new-ai-gateway-url',
              'duoCoreFeaturesEnabled' => nil
            )
            expect(result['errors']).to eq([])

            expect(application_settings.reload.ai_gateway_url).to eq('http://new-ai-gateway-url')
            expect { duo_settings.reload }.to not_change { duo_settings.duo_core_features_enabled }
          end
        end

        context 'when updating minimum_access_level_execute' do
          let(:mutation_params) { { minimum_access_level_execute: 'DEVELOPER' } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_execute).to eq(::Gitlab::Access::DEVELOPER)
            expect(result['duoSettings']).to include(
              'minimumAccessLevelExecute' => 'DEVELOPER'
            )
          end

          it 'does not update the field when the feature flag is disabled' do
            stub_feature_flags(dap_instance_customizable_permissions: false)

            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_execute).to be_nil
            expect(result['duoSettings']).to include(
              'minimumAccessLevelExecute' => nil
            )
          end
        end

        context 'when updating minimum_access_level_execute_async' do
          let(:mutation_params) { { minimum_access_level_execute_async: 'DEVELOPER' } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_execute_async).to eq(::Gitlab::Access::DEVELOPER)
            expect(result['duoSettings']).to include(
              'minimumAccessLevelExecuteAsync' => 'DEVELOPER'
            )
          end

          it 'does not update the field when the feature flag is disabled' do
            stub_feature_flags(dap_instance_customizable_permissions: false)

            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_execute_async).to be_nil
            expect(result['duoSettings']).to include(
              'minimumAccessLevelExecuteAsync' => nil
            )
          end
        end

        context 'when updating minimum_access_level_manage' do
          let(:mutation_params) { { minimum_access_level_manage: 'DEVELOPER' } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_manage).to eq(::Gitlab::Access::DEVELOPER)
            expect(result['duoSettings']).to include(
              'minimumAccessLevelManage' => 'DEVELOPER'
            )
          end

          it 'does not update the field when the feature flag is disabled' do
            stub_feature_flags(dap_instance_customizable_permissions: false)

            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_manage).to be_nil
            expect(result['duoSettings']).to include(
              'minimumAccessLevelManage' => nil
            )
          end
        end

        context 'when updating minimum_access_level_enable_on_projects' do
          let(:mutation_params) { { minimum_access_level_enable_on_projects: 'MAINTAINER' } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_enable_on_projects).to eq(::Gitlab::Access::MAINTAINER)
            expect(result['duoSettings']).to include(
              'minimumAccessLevelEnableOnProjects' => 'MAINTAINER'
            )
          end

          it 'does not update the field when the feature flag is disabled' do
            stub_feature_flags(dap_instance_customizable_permissions: false)

            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.minimum_access_level_enable_on_projects).to be_nil
            expect(result['duoSettings']).to include(
              'minimumAccessLevelEnableOnProjects' => nil
            )
          end
        end

        context 'when updating include_recommended_allowed' do
          let(:mutation_params) { { include_recommended_allowed: true } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.include_recommended_allowed).to be(true)
            expect(result['duoSettings']).to include(
              'includeRecommendedAllowed' => true
            )
          end
        end

        context 'when updating allow_all_unix_sockets' do
          let(:mutation_params) { { allow_all_unix_sockets: true } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.allow_all_unix_sockets).to be(true)
            expect(result['duoSettings']).to include(
              'allowAllUnixSockets' => true
            )
          end
        end

        context 'when updating allow_project_extension' do
          let(:mutation_params) { { allow_project_extension: false } }

          it 'updates the field' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(duo_settings.reload.allow_project_extension).to be(false)
            expect(result['duoSettings']).to include(
              'allowProjectExtension' => false
            )
          end
        end

        context 'when updating duo_cli_enabled' do
          let(:mutation_params) { { duo_cli_enabled: false } }

          it 'updates the duo_cli_enabled setting' do
            expect(duo_settings.duo_cli_enabled).to be(true) # default is true

            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['errors']).to eq([])
            expect { duo_settings.reload }.to change { duo_settings.duo_cli_enabled }.from(true).to(false)
          end

          it 'returns the updated value in the response' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['duoSettings']).to include(
              'duoCliEnabled' => false
            )
          end
        end

        context 'when re-enabling duo_cli_enabled' do
          let(:mutation_params) { { duo_cli_enabled: true } }

          before do
            duo_settings.update!(duo_cli_enabled: false)
          end

          it 'updates the duo_cli_enabled setting to true' do
            request

            result = json_response['data']['duoSettingsUpdate']

            expect(result['errors']).to eq([])
            expect { duo_settings.reload }.to change { duo_settings.duo_cli_enabled }.from(false).to(true)
          end
        end
      end
    end
  end
end
