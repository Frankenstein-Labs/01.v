# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSettingSelectionService, feature_category: :"self-hosted_models" do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:root_namespace) { create(:group, organization: organization) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
  let_it_be(:code_completions_ai_feature_setting) do
    create(:ai_feature_setting,
      self_hosted_model: self_hosted_model,
      feature: :code_completions
    )
  end

  let(:feature) { :duo_chat }
  let(:service) { described_class.new(user, feature, root_namespace) }

  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
  end

  describe '#execute' do
    subject(:response) { service.execute }

    before do
      allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(default_duo_namespace)
    end

    let(:default_duo_namespace) { nil }

    context 'when AmazonQ is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
      end

      it 'returns success with nil payload' do
        expect(response).to be_success
        expect(response.payload).to be_nil
      end
    end

    context 'when running on GitLab.com or GitLab.org' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when root namespace is present' do
        before_all do
          root_namespace.add_developer(user)
        end

        context 'when feature setting does not exist' do
          it 'returns success with namespace feature setting' do
            expect(response).to be_success
            expect(response.payload).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
            expect(response.payload.namespace).to eq(root_namespace)
            expect(response.payload.feature).to eq(feature.to_s)
          end
        end

        context 'when feature setting already exists' do
          let!(:existing_setting) do
            create(:ai_namespace_feature_setting, namespace: root_namespace, feature: feature,
              offered_model_ref: "claude-3-7-sonnet-20250219")
          end

          it 'returns the existing feature setting' do
            expect(response).to be_success
            expect(response.payload).to eq(existing_setting)
          end
        end
      end

      context 'when root namespace is nil' do
        let(:root_namespace) { nil }

        context 'when user has a default duo namespace' do
          let(:default_duo_namespace) { create(:group, organization: organization) }

          it 'returns success with namespace feature setting for default namespace' do
            expect(response).to be_success
            expect(response.payload).to be_a(::Ai::ModelSelection::NamespaceFeatureSetting)
            expect(response.payload.namespace).to eq(default_duo_namespace)
            expect(response.payload.feature).to eq(feature.to_s)
          end
        end

        context 'when user has no default duo namespace' do
          context 'when default duo namespace is required' do
            before do
              allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group).and_return(true)
            end

            it 'returns error with missing default namespace message' do
              expect(response).to be_error
              expect(response.payload).to be_nil
              expect(response.message).to eq(described_class::MISSING_DEFAULT_NAMESPACE)
            end
          end

          context 'when default duo namespace is not required' do
            before do
              allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group).and_return(false)
            end

            it 'returns success with nil payload' do
              expect(response).to be_success
              expect(response.payload).to be_nil
            end
          end
        end
      end
    end

    context 'when running on self-hosted instance' do
      context 'when self-hosted feature setting exists and is not vendored' do
        let_it_be(:ai_feature_setting) do
          create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat)
        end

        it 'returns success with self-hosted feature setting' do
          expect(response).to be_success
          expect(response.payload).to eq(ai_feature_setting)
        end
      end

      context 'when self-hosted feature setting exists and is vendored' do
        let_it_be(:vendored_feature_setting) do
          create(:ai_feature_setting, feature: :duo_chat, provider: :vendored)
        end

        it 'returns success with instance level setting' do
          expect(response).to be_success
          expect(response.payload).to be_a(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          expect(response.payload.feature).to eq(feature.to_s)
        end
      end

      context 'when self-hosted feature setting does not exist' do
        context 'and self-hosted AI Gateway has not been configured' do
          it 'returns success with default instance level setting' do
            expect(response).to be_success
            expect(response.payload.set_to_gitlab_default?).to be(true)
            expect(response.payload).not_to be_persisted
            expect(response.payload.feature).to eq(feature.to_s)
          end
        end

        context 'and the instance is on an offline cloud license' do
          let_it_be(:license) { create(:license) }

          before do
            stub_application_setting(ai_gateway_url: 'http://ai-gateway.example.com')
            allow(::License).to receive(:current).and_return(license)
            allow(license).to receive(:offline_cloud_license?).and_return(true)
          end

          it 'does not create a default vendored instance setting and returns nil instead', :aggregate_failures do
            expect(response).to be_success
            expect(response.payload).to be_nil
          end
        end

        context 'and the instance is on an online cloud license' do
          let_it_be(:license) { create(:license) }

          before do
            allow(::License).to receive(:current).and_return(license)
            allow(license).to receive(:offline_cloud_license?).and_return(false)
          end

          context 'and a self-hosted AI Gateway is configured (hybrid)' do
            before do
              stub_application_setting(ai_gateway_url: 'http://ai-gateway.example.com')
            end

            context 'and the instance setting is the GitLab default model' do
              let_it_be(:instance_setting) do
                create(:instance_model_selection_feature_setting, feature: :duo_chat, offered_model_ref: nil)
              end

              it 'returns the GitLab default instance setting',
                :aggregate_failures do
                expect(response).to be_success
                expect(response.payload).to eq(instance_setting)
                expect(response.payload.set_to_gitlab_default?).to be(true)
              end
            end

            context 'and the instance setting is a non-default model' do
              let_it_be(:instance_setting) do
                create(:instance_model_selection_feature_setting, feature: :duo_chat)
              end

              it 'returns the selected instance setting' do
                expect(response).to be_success
                expect(response.payload.offered_model_ref).to eq('claude-3-7-sonnet-20250219')
              end
            end
          end
        end
      end

      context 'when instance level setting already exists' do
        let_it_be(:instance_setting) do
          create(:instance_model_selection_feature_setting, feature: :duo_chat)
        end

        it 'returns the existing instance level setting' do
          expect(response).to be_success
          expect(response.payload).to eq(instance_setting)
        end
      end

      context 'when both self-hosted and instance settings exist' do
        let_it_be(:ai_feature_setting) do
          create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat)
        end

        let_it_be(:instance_setting) do
          create(:instance_model_selection_feature_setting, feature: :duo_chat)
        end

        it 'prioritizes self-hosted feature setting over instance setting' do
          expect(response).to be_success
          expect(response.payload).to eq(ai_feature_setting)
        end
      end
    end
  end
end
