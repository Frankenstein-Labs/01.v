# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resolvers::Ai::ModelSelection::Namespaces::FeatureSettingsResolver,
  feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:args) { { group_id: GitlabSchema.id_from_object(group) } }

  # Add current user as group owner for authorization
  before_all do
    group.add_owner(current_user)
  end

  describe "#resolve" do
    subject(:resolver) do
      resolve(described_class, obj: nil, args: args, ctx: { current_user: current_user })
    end

    # Common test data
    let(:model_definitions) do
      {
        "models" => [
          { "identifier" => "model1", "name" => "Model 1", "provider" => "anthropic" },
          { "identifier" => "model2", "name" => "Model 2", "provider" => "openai" }
        ],
        "unit_primitives" => [
          {
            "feature_setting" => "duo_chat",
            "default_model" => "model1",
            "selectable_models" => %w[model1 model2]
          }
        ]
      }
    end

    # Common service response
    let(:service_result) { ServiceResponse.success(payload: model_definitions) }

    # Common mocks setup
    before do
      # Mock model definitions fetch service
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(service_result)
      end

      # Mock feature setting finder with empty result by default
      allow_next_instance_of(::Ai::ModelSelection::Namespaces::FeatureSettingFinder) do |finder|
        allow(finder).to receive(:execute).and_return([])
      end

      # Important: Mock the authorization check
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
                          .with(current_user, :admin_group_model_selection, group)
                          .and_return(true)

      # Mock the settings to allow model selection
      allow(group.namespace_settings).to receive(:duo_features_enabled?).and_return(true)
      allow(::Ai::Setting).to receive(:self_hosted?).and_return(false)
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
      allow(group).to receive(:root?).and_return(true)
    end

    context "when user is authorized" do
      it "decorates feature settings with appropriate parameters" do
        expect(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
          .to receive(:decorate)
                .with(
                  anything,
                  model_definitions: model_definitions,
                  current_user: current_user
                )
                .and_call_original

        resolver
      end
    end

    context "when user is not authorized" do
      let_it_be(:unauthorized_user) { create(:user) }

      subject(:unauthorized_resolver) do
        resolve(described_class, obj: nil, args: args, ctx: { current_user: unauthorized_user })
      end

      before do
        allow(Ability).to receive(:allowed?)
                            .with(unauthorized_user, :admin_group_model_selection, anything)
                            .and_return(false)
      end

      it "raises a ResourceNotAvailable error" do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          unauthorized_resolver
        end
      end
    end

    context "when service fails" do
      let(:service_result) { ServiceResponse.error(message: "Service failed") }

      it "raises a ResourceNotAvailable error" do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolver
        end
      end
    end

    context "when feature settings exist" do
      let_it_be(:feature_setting) do
        create(:ai_namespace_feature_setting, namespace: group, feature: :duo_chat, offered_model_ref: nil)
      end

      before do
        allow_next_instance_of(::Ai::ModelSelection::Namespaces::FeatureSettingFinder) do |finder|
          allow(finder).to receive(:execute).and_return([feature_setting])
        end
      end

      it "decorates feature settings with model definitions" do
        result = resolver

        expect(result).to be_a(Gitlab::Graphql::Pagination::ArrayConnection)
        expect(result.items.first).to be_a(Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
      end

      it "passes all required parameters to decorator" do
        expect(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
          .to receive(:decorate)
                .with(
                  [feature_setting],
                  model_definitions: model_definitions,
                  current_user: current_user
                )
                .and_call_original

        resolver
      end

      context "when group is nil" do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:authorized_find!).and_return(nil)
          end
        end

        it "decorates feature settings without a group_id" do
          expect(::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting)
            .to receive(:decorate)
                  .with(
                    anything,
                    model_definitions: model_definitions,
                    current_user: current_user
                  )
                  .and_call_original

          resolver
        end
      end
    end
  end
end
