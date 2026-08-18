# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageQuotaService, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  describe '#usage_quota_check' do
    let(:event_type) { :rails_on_ui_check }

    let(:feature_metadata) do
      Gitlab::SubscriptionPortal::FeatureMetadata::Feature.new(
        feature_qualified_name: 'dap_feature_legacy',
        feature_ai_catalog_item: nil
      )
    end

    let(:static_params) do
      { event_type: event_type, feature_qualified_name: feature_metadata.feature_qualified_name }
    end

    before do
      allow(::Gitlab::SubscriptionPortal::FeatureMetadata)
        .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)
    end

    shared_examples 'usage quota caching' do
      describe 'caching', :use_clean_rails_memory_store_caching do
        before do
          Rails.cache.clear
        end

        it 'includes plan in the cache key' do
          expect(Digest::SHA256).to receive(:hexdigest).with(including(':plan_key,')).and_call_original

          described_class.new(**service_params).execute
        end

        it 'caches with server-provided TTL when present' do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:verify_usage_quota).and_return({ success: true, cache_ttl: 300 })

          expect(Rails.cache).to receive(:write).with(
            including(/usage_quota_dot_query:\b[a-f0-9]{64}\b/),
            anything,
            expires_in: 300
          ).and_call_original

          described_class.new(**service_params).execute
        end

        it 'falls back to 1 hour when server does not provide cache TTL' do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:verify_usage_quota).and_return({ success: true })

          expect(Rails.cache).to receive(:write).with(
            including(/usage_quota_dot_query:\b[a-f0-9]{64}\b/),
            anything,
            expires_in: 1.hour
          ).and_call_original

          described_class.new(**service_params).execute
        end

        it 'enforces a minimum cache TTL' do
          allow(::Gitlab::SubscriptionPortal::Client)
            .to receive(:verify_usage_quota).and_return({ success: true, cache_ttl: 0 })

          expect(Rails.cache).to receive(:write).with(
            including(/usage_quota_dot_query:\b[a-f0-9]{64}\b/),
            anything,
            expires_in: 30.seconds
          ).and_call_original

          described_class.new(**service_params).execute
        end

        it 'uses cached response on subsequent calls' do
          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).once

          described_class.new(**service_params).execute
          described_class.new(**service_params).execute
        end

        it 'generates different cache keys for different event type' do
          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).twice

          described_class.new(**service_params).execute
          described_class.new(**service_params.merge(event_type: :custom_event)).execute
        end
      end
    end

    context 'when running on GitLab.com', :saas do
      let(:base_params) { static_params.merge(realm: 'saas') }

      shared_examples 'falling back to default namespace' do
        context 'when default namespace selected by user' do
          let_it_be(:default_namespace) { create(:group) }

          before do
            allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
          end

          it 'calls portal with default namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
            expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
              .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

            expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
              **base_params,
              user_id: user.id,
              root_namespace_id: default_namespace.id
            })

            service_call
          end
        end

        it 'returns error' do
          expect(service_call).to be_error
          expect(service_call[:reason]).to eq(:namespace_missing)
        end
      end

      subject(:service_call) { described_class.new(user: user).execute }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when namespace is not provided' do
        it_behaves_like 'falling back to default namespace'
      end

      context 'when namespace is provided' do
        subject(:service_call) { described_class.new(user: user, namespace: namespace).execute }

        let_it_be(:root_namespace) { create(:group) }
        let_it_be(:namespace) { create(:group, parent: root_namespace) }

        context 'when the user can invoke the feature in the given namespace' do
          before do
            allow(user).to receive(:governing_namespace).with(root_namespace).and_return(root_namespace)
          end

          context 'when the user is a gitlab team member' do
            before do
              stub_feature_flags(enable_quota_check_for_team_members: false)
              allow(user).to receive(:gitlab_team_member?).and_return(true)
            end

            it 'is successful' do
              expect(::Gitlab::SubscriptionPortal::Client).not_to receive(:verify_usage_quota)
              expect(service_call).to be_success
            end

            context 'when enable_quota_check_for_team_members is enabled' do
              before do
                stub_feature_flags(enable_quota_check_for_team_members: true)
              end

              it 'is verifies usage' do
                expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota)
                expect(service_call).to be_success
              end
            end
          end

          context 'when usage quota is available' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
            end

            it 'calls portal with provided namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
              expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
                .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
                **base_params,
                user_id: user.id,
                root_namespace_id: root_namespace.id
              })

              expect(service_call).to be_success
            end

            it_behaves_like 'usage quota caching' do
              let(:service_params) { { user: user, namespace: namespace } }

              context 'when using mock endpoint' do
                before do
                  stub_feature_flags(use_mock_dot_api_for_usage_quota: true)
                  stub_rails_env('development')
                end

                it 'does not cache the response' do
                  expect(Rails.cache).not_to receive(:read)
                  expect(Rails.cache).not_to receive(:write)

                  described_class.new(**service_params).execute
                end

                it 'makes HTTP request on every call' do
                  expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).twice

                  described_class.new(**service_params).execute
                  described_class.new(**service_params).execute
                end
              end
            end
          end

          context 'when usage quota is not available (402)' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
                **base_params,
                user_id: user.id,
                root_namespace_id: root_namespace.id
              }).and_return({ success: false, data: { errors: "HTTP status code: 402" } }.with_indifferent_access)
            end

            it 'calls portal with provided namespace, dap_feature_legacy metadata, and rails_on_ui_check event type' do
              expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
                .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

              expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
                **base_params,
                user_id: user.id,
                root_namespace_id: root_namespace.id
              })

              expect(service_call).to be_error
              expect(service_call[:reason]).to eq(:usage_quota_exceeded)
            end
          end

          context 'when usage billing is forbidden (403)' do
            before do
              allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
                **base_params,
                user_id: user.id,
                root_namespace_id: root_namespace.id
              }).and_return({ success: false, data: { errors: "HTTP status code: 403" } }.with_indifferent_access)
            end

            it 'returns usage_billing_forbidden error' do
              expect(service_call).to be_error
              expect(service_call[:reason]).to eq(:usage_billing_forbidden)
            end
          end
        end

        context 'when the user is not allowed to invoke the feature in the given namespace' do
          it_behaves_like 'falling back to default namespace'
        end
      end
    end

    context 'when running on self-hosted instance' do
      let(:unique_instance_id) { 'instance_id' }
      let(:real_unique_instance_id) { 'uniq_instance_id' }

      let(:params) do
        static_params.merge(
          realm: 'self-managed',
          user_id: user.id,
          unique_instance_id: unique_instance_id,
          instance_id: unique_instance_id,
          instance_version: Gitlab.version_info.to_s
        )
      end

      subject(:service_call) { described_class.new(user: user).execute }

      before do
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })

        allow(::Gitlab::GlobalAnonymousId)
          .to receive_messages(instance_id: unique_instance_id, instance_uuid: real_unique_instance_id)
      end

      context 'when on paid license' do
        before do
          create_current_license
        end

        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(params)

          service_call
        end

        it_behaves_like 'usage quota caching' do
          let(:service_params) { { user: user } }
        end
      end

      context 'when on trial' do
        let(:unique_instance_id) { real_unique_instance_id }

        before do
          create_current_license(:trial)
        end

        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(params)

          service_call
        end
      end

      context 'when no license exists', :without_license do
        it 'calls portal with instance id, dap_feature_legacy metadata, and rails_on_ui_check event type' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(params)

          service_call
        end
      end
    end

    context 'when custom event_type is provided' do
      subject(:service_call) do
        described_class.new(user: user, event_type: :custom_event).execute
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(create(:group, id: 999))
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
      end

      it 'uses the custom event_type instead of default rails_on_ui_check' do
        expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
          .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

        expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with({
          event_type: :custom_event,
          user_id: user.id,
          realm: 'self-managed',
          feature_qualified_name: feature_metadata.feature_qualified_name,
          root_namespace_id: 999
        })

        service_call
      end
    end

    context 'when user is not present' do
      subject(:service_call) { described_class.new(user: nil).execute }

      it "returns error that user is not present" do
        expect(service_call).to be_error
        expect(service_call[:reason]).to eq(:user_missing)
      end
    end

    context 'when workflow_definition is provided' do
      let_it_be(:default_namespace) { create(:group) }
      let(:workflow_definition) { 'sast_fp_detection/v1' }

      subject(:service_call) do
        described_class.new(
          user: user,
          workflow_definition: workflow_definition
        ).execute
      end

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_namespace)
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
      end

      it 'uses workflow-specific feature metadata instead of dap_feature_legacy' do
        expect(::Gitlab::SubscriptionPortal::FeatureMetadata).not_to receive(:for)

        expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(hash_including(
          event_type: :rails_on_ui_check,
          feature_qualified_name: 'sast_fp_detection/v1',
          feature_ai_catalog_item: false,
          user_id: user.id,
          root_namespace_id: default_namespace.id
        ))

        service_call
      end

      context 'when workflow_definition is the default :dap_feature_legacy symbol' do
        let(:workflow_definition) { :dap_feature_legacy }

        it 'uses dap_feature_legacy metadata' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(hash_including(
            event_type: :rails_on_ui_check,
            feature_qualified_name: feature_metadata.feature_qualified_name,
            user_id: user.id,
            root_namespace_id: default_namespace.id
          ))

          service_call
        end
      end

      context 'when workflow_definition is the string "dap_feature_legacy"' do
        let(:workflow_definition) { 'dap_feature_legacy' }

        it 'uses dap_feature_legacy metadata' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(hash_including(
            event_type: :rails_on_ui_check,
            feature_qualified_name: feature_metadata.feature_qualified_name,
            user_id: user.id,
            root_namespace_id: default_namespace.id
          ))

          service_call
        end
      end

      context 'when workflow_definition is nil' do
        let(:workflow_definition) { nil }

        it 'uses dap_feature_legacy metadata' do
          expect(::Gitlab::SubscriptionPortal::FeatureMetadata)
            .to receive(:for).with(:dap_feature_legacy).and_return(feature_metadata)

          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(hash_including(
            event_type: :rails_on_ui_check,
            feature_qualified_name: feature_metadata.feature_qualified_name,
            user_id: user.id,
            root_namespace_id: default_namespace.id
          ))

          service_call
        end
      end

      context 'when feature_ai_catalog_item is true' do
        subject(:service_call) do
          described_class.new(
            user: user,
            workflow_definition: 'chat',
            feature_ai_catalog_item: true
          ).execute
        end

        it 'passes feature_ai_catalog_item as true in the metadata' do
          expect(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).with(hash_including(
            event_type: :rails_on_ui_check,
            feature_qualified_name: 'chat',
            feature_ai_catalog_item: true,
            user_id: user.id,
            root_namespace_id: default_namespace.id
          ))

          service_call
        end
      end
    end

    context 'when subscription portal call results in error' do
      subject(:service_call) { described_class.new(user: user).execute }

      before do
        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_raise(StandardError.new)
      end

      it "does not block user access" do
        expect(Gitlab::AppLogger).to receive(:error).with(
          message: 'Failed to verify usage quota',
          logging_error: be_a(String),
          Labkit::Fields::GL_USER_ID => user.id
        )

        expect(service_call).to be_success
      end
    end
  end
end
