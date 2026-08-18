# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ModelDetails::CodeCompletion, feature_category: :code_suggestions do
  include GitlabSubscriptions::SaasSetAssignmentHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }

  let_it_be(:group1_addon) do
    create(
      :gitlab_subscription_add_on_purchase,
      add_on: create(:gitlab_subscription_add_on, :duo_pro),
      namespace: group1
    ).tap do |addon|
      add_user_to_group(user, addon)
    end
  end

  let_it_be(:group2_addon) do
    create(
      :gitlab_subscription_add_on_purchase,
      add_on: create(:gitlab_subscription_add_on, :duo_enterprise),
      namespace: group2
    ).tap do |addon|
      add_user_to_group(user, addon)
    end
  end

  let(:completions_model_details) { described_class.new(current_user: user) }

  before do
    allow(user.user_preference).to receive(:duo_default_namespace_with_fallback).and_return(group1)
    # we add default namespaces to account for no context calls
    # For model selection see https://gitlab.com/gitlab-org/gitlab/-/issues/552082
    # Is test in ee/spec/lib/code_suggestions/model_details/base_spec.rb
    # And CodeSuggestions::ModelDetails::Base#model_selection_feature_setting for more context
  end

  shared_examples 'selects the correct model' do
    context 'on GitLab self-managed' do
      before do
        allow(Gitlab).to receive(:org_or_com?).and_return(false)
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns the fireworks/codestral model' do
        expect(actual_result).to eq(expected_fireworks_codestral_result)
      end
    end

    context 'on GitLab saas' do
      before do
        allow(Gitlab).to receive(:org_or_com?).and_return(true)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns the fireworks/codestral model' do
        expect(actual_result).to eq(expected_fireworks_codestral_result)
      end
    end

    context 'when code_completions is self-hosted' do
      before do
        feature_setting_double = instance_double(::Ai::FeatureSetting, self_hosted?: true, vendored?: false)
        allow(::Ai::FeatureSetting).to receive(:find_by_feature).with('code_completions')
          .and_return(feature_setting_double)
      end

      it 'returns the self-hosted model' do
        expect(actual_result).to eq(expected_self_hosted_model_result)
      end
    end
  end

  describe '#current_model' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.current_model }

      let(:expected_fireworks_codestral_result) do
        {
          model_provider: 'fireworks_ai',
          model_name: 'codestral-2508'
        }
      end

      let(:expected_self_hosted_model_result) { {} }

      context 'when instance duo self-hosted config exists' do
        context 'and is not set to vendored' do
          let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }

          before do
            create(:ai_feature_setting,
              self_hosted_model: self_hosted_model,
              provider: :self_hosted,
              feature: 'code_completions')
          end

          it 'returns empty response' do
            expect(actual_result).to eq(expected_self_hosted_model_result)
          end
        end

        context 'and is set to vendored' do
          context 'and instance level is not default' do
            before do
              create(:instance_model_selection_feature_setting,
                feature: 'code_completions',
                offered_model_ref: 'claude_sonnet_3_5')
            end

            it 'returns the selected model' do
              expect(actual_result).to eq({
                model_provider: 'gitlab',
                model_name: 'claude_sonnet_3_5'
              })
            end
          end

          context 'and has chosen a remapped model' do
            before do
              create(:instance_model_selection_feature_setting,
                feature: 'code_completions',
                offered_model_ref: 'codestral_2501_vertex')
            end

            it 'returns the selected model' do
              expect(actual_result).to eq({
                model_provider: 'gitlab',
                model_name: 'codestral_2508_vertex'
              })
            end
          end

          context 'and instance level is default' do
            it 'returns the default model' do
              expect(actual_result).to eq(expected_fireworks_codestral_result)
            end
          end
        end
      end
    end
  end

  describe '#saas_primary_model_class' do
    it_behaves_like 'selects the correct model' do
      subject(:actual_result) { completions_model_details.saas_primary_model_class }

      let(:expected_fireworks_codestral_result) do
        CodeSuggestions::Prompts::CodeCompletion::FireworksCodestral
      end

      let(:expected_self_hosted_model_result) { nil }
    end
  end

  describe 'initialization with root_namespace' do
    let_it_be(:specific_namespace) { create(:group) }
    let_it_be(:project_in_namespace) { create(:project, group: specific_namespace) }

    context 'when root_namespace is provided' do
      let(:model_details) { described_class.new(current_user: user, root_namespace: specific_namespace) }

      it 'initializes with the provided root_namespace' do
        expect(model_details.instance_variable_get(:@root_namespace)).to eq(specific_namespace)
      end

      it 'passes root_namespace to FeatureSettingSelectionService' do
        expect(Ai::FeatureSettingSelectionService).to receive(:new).with(
          user,
          'code_completions',
          specific_namespace
        ).and_call_original

        model_details.feature_setting
      end
    end

    context 'when root_namespace is not provided' do
      let(:model_details) { described_class.new(current_user: user) }

      it 'initializes with nil root_namespace' do
        expect(model_details.instance_variable_get(:@root_namespace)).to be_nil
      end

      it 'passes nil root_namespace to FeatureSettingSelectionService' do
        expect(Ai::FeatureSettingSelectionService).to receive(:new).with(
          user,
          'code_completions',
          nil
        ).and_call_original

        model_details.feature_setting
      end
    end
  end
end
