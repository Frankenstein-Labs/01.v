# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSetting, feature_category: :"self-hosted_models" do
  subject { build(:ai_feature_setting) }

  it { is_expected.to belong_to(:self_hosted_model) }
  it { is_expected.to validate_presence_of(:feature) }
  it { is_expected.to validate_uniqueness_of(:feature).ignoring_case_sensitivity }
  it { is_expected.to validate_presence_of(:provider) }

  describe 'when ::Ai::FeatureConfigurable is included' do
    let(:feature_setting) { create(:ai_feature_setting) }

    it_behaves_like '#metadata is defined for AI configurable features'

    context 'with request model info' do
      context 'when model info should be resolved' do
        it_behaves_like 'configurable AI features resolves model info correctly' do
          # results for #model_metadata_params and #model_request_params
          # are expected to be different
          let(:expected_params_for_metadata) do
            {
              api_key: "token",
              endpoint: "http://localhost:11434/v1",
              identifier: "provider/some-model",
              name: "mistral",
              provider: :openai
            }
          end

          let(:expected_params_for_request) do
            {
              provider: :litellm,
              model: "mistral",
              model_endpoint: "http://localhost:11434/v1",
              model_api_key: "token",
              model_identifier: "provider/some-model"
            }
          end
        end
      end

      context 'when the feature setting has no self-hosted model' do
        it_behaves_like 'configurable AI features resolves model info correctly' do
          let(:feature_setting) { create(:ai_feature_setting, provider: :disabled, self_hosted_model: nil) }
          let(:expected_params_for_metadata) { nil }
          let(:expected_params_for_request) { nil }
        end
      end

      context 'when self_hosted? returns false' do
        before do
          allow(feature_setting).to receive(:self_hosted?).and_return(false)
        end

        it_behaves_like 'configurable AI features resolves model info correctly' do
          let(:feature_setting) { create(:ai_feature_setting) }
          let(:expected_params_for_metadata) { nil }
          let(:expected_params_for_request) { nil }
        end
      end

      context 'when feature setting is vendored' do
        it_behaves_like 'configurable AI features resolves model info correctly' do
          let(:feature_setting) { create(:ai_feature_setting, provider: :vendored, feature: :duo_chat) }
          let(:expected_params_as_if_gitlab_default_model) do
            {
              provider: 'gitlab',
              identifier: '',
              feature_setting: 'duo_chat'
            }
          end

          let(:expected_params_for_metadata) { expected_params_as_if_gitlab_default_model }
          let(:expected_params_for_request) { expected_params_as_if_gitlab_default_model }
        end
      end
    end
  end

  context 'when feature setting is self hosted' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it { expect(feature_setting).to validate_presence_of(:self_hosted_model) }
    it { expect(feature_setting.provider_title).to eq('Self-hosted model (mistral-7b-ollama-api)') }
  end

  context 'when feature setting is vendored' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :vendored) }

    it { expect(feature_setting.provider_title).to eq('GitLab AI vendor model') }
  end

  context 'when feature setting is disabled' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :disabled) }

    it { expect(feature_setting.provider_title).to eq('Disabled') }
  end

  describe '.for_self_hosted_model' do
    let_it_be(:self_hosted_model) do
      create(:ai_self_hosted_model, name: 'model', model: :mistral)
    end

    let_it_be(:feature_setting) do
      create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :code_completions,
        provider: :self_hosted)
    end

    let_it_be(:other_self_hosted_model) do
      create(:ai_self_hosted_model, name: 'other_model', model: :codegemma)
    end

    let_it_be(:other_feature_setting) do
      create(:ai_feature_setting, self_hosted_model: other_self_hosted_model, feature: :code_generations,
        provider: :self_hosted)
    end

    context 'when the self-hosted model exists' do
      it 'returns feature settings for the specified self-hosted model' do
        result = described_class.for_self_hosted_model(self_hosted_model.id)

        expect(result).to match_array([feature_setting])
      end
    end

    context 'when the self-hosted model does not exist' do
      it 'returns an empty collection' do
        result = described_class.for_self_hosted_model(non_existing_record_id)

        expect(result).to be_empty
      end
    end
  end

  describe '.allowed_features' do
    let_it_be(:stable_features) { Ai::FeatureSetting::STABLE_FEATURES.dup.stringify_keys }
    let_it_be(:feature_flagged_features) { Ai::FeatureSetting::FLAGGED_FEATURES.dup.stringify_keys }

    before do
      # Set testing terms to false by default to make sure we catch
      # undesirable mutations https://gitlab.com/gitlab-org/gitlab/-/issues/560746
      allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(false)
    end

    context 'when GitLab testing terms have not been accepted' do
      it 'returns only stable features' do
        expect(described_class.allowed_features).to eq(stable_features)
      end

      it 'does not include flagged features' do
        expect(described_class.allowed_features.keys).not_to include(*feature_flagged_features.keys)
      end
    end

    context 'when GitLab testing terms have been accepted' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
      end

      it 'returns both stable and flagged features' do
        expect(described_class.allowed_features).to eq(stable_features.merge(feature_flagged_features))
      end
    end

    context 'when current license is premium' do
      before do
        allow(::License).to receive(:current).and_return(instance_double(License, premium?: true))
      end

      context 'when GitLab testing terms have been accepted' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
        end

        it 'excludes restricted features for premium users' do
          expected_features = stable_features.merge(feature_flagged_features)
          expected_features.except!(
            'duo_chat_explain_vulnerability',
            'resolve_vulnerability'
          )

          expect(described_class.allowed_features).to eq(expected_features)
        end
      end

      context 'when GitLab testing terms have not been accepted' do
        it 'returns only stable features' do
          expect(described_class.allowed_features).to eq(stable_features)
        end

        it 'does not include flagged features' do
          expect(described_class.allowed_features.keys).not_to include(*feature_flagged_features.keys)
        end
      end
    end

    context 'when features are controlled by feature flags' do
      before do
        allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
      end

      it 'includes duo_agent_platform' do
        expect(described_class.allowed_features.keys).to include('duo_agent_platform')
      end

      context 'when premium license restrictions also apply' do
        before do
          allow(::License).to receive(:current).and_return(instance_double(License, premium?: true))
        end

        it 'applies both feature flag and license restrictions' do
          expected_features = stable_features.merge(feature_flagged_features)
          expected_features.except!(
            'duo_chat_explain_vulnerability', # excluded by premium license
            'resolve_vulnerability' # excluded by premium license
          )

          expect(described_class.allowed_features).to eq(expected_features)
        end
      end
    end
  end

  describe '#base_url' do
    let(:url) { "http://localhost:5000" }
    let(:cloud_connector_url) { "http://staging.cloud.gitlab.com/ai" }

    it 'returns Gitlab::AiGateway.url for self hosted features' do
      expect(Gitlab::AiGateway).to receive(:url).and_return(url)

      expect(build(:ai_feature_setting, provider: :self_hosted).base_url).to eq(url)
    end

    it 'returns `Gitlab::AiGateway.cloud_connector_url` for vendored features' do
      expect(Gitlab::AiGateway).to receive(:cloud_connector_url).and_return(cloud_connector_url)

      expect(build(:ai_feature_setting, provider: :vendored).base_url).to eq(cloud_connector_url)
    end

    it 'returns `nil` for disabled features' do
      expect(build(:ai_feature_setting, provider: :disabled).base_url).to be_nil
    end
  end

  describe 'validation of self-hosted model' do
    let(:feature_setting) { build(:ai_feature_setting, feature: :duo_chat) }
    let(:self_hosted_model) { create(:ai_self_hosted_model) }

    context 'when provider is not self_hosted' do
      it 'does not add any errors' do
        feature_setting.provider = :vendored
        feature_setting.validate
        expect(feature_setting.errors[:self_hosted_model]).to be_empty
      end
    end

    context 'when provider is self_hosted' do
      before do
        feature_setting.provider = :self_hosted
        feature_setting.self_hosted_model = self_hosted_model
      end

      context 'when compatible_llms is not present' do
        it 'does not add any errors' do
          allow(feature_setting).to receive(:compatible_llms).and_return([])
          feature_setting.validate
          expect(feature_setting.errors[:self_hosted_model]).to be_empty
        end
      end

      context 'when compatible_llms is present' do
        let(:compatible_llms) { %w[mistral deepseekcoder codegemma] }

        before do
          allow(feature_setting).to receive(:compatible_llms).and_return(compatible_llms)
        end

        context 'when self_hosted_model is compatible' do
          it 'does not add any errors' do
            self_hosted_model.model = :mistral
            feature_setting.validate
            expect(feature_setting.errors[:self_hosted_model]).to be_empty
          end
        end

        context 'when self_hosted_model is not compatible' do
          it 'adds an error message' do
            incompatible_model = :codellama
            self_hosted_model.model = incompatible_model
            feature_setting.validate
            expect(feature_setting.errors[:base])
              .to include("#{incompatible_model.capitalize} is incompatible with the #{feature_setting.title} feature")
          end
        end
      end
    end
  end

  describe 'feature constants' do
    shared_examples_for 'feature metadata validation' do |features, expected_release_states|
      it 'has valid metadata for all features', :aggregate_failures do
        features.each_key do |feature|
          expect(::Ai::FeatureConfigurable::FEATURE_METADATA.keys).to include(feature.to_s),
            "Expected #{feature} to have valid metadata in `feature_metadata.yml`, but it does not exist. " \
              "Please add it."
          metadata = ::Ai::FeatureConfigurable::FEATURE_METADATA.fetch(feature.to_s, {})
          expect(metadata).to include('title', 'main_feature', 'compatible_llms', 'release_state')
          expect(metadata.fetch('release_state', 'no value')).to be_in(expected_release_states),
            "Expected #{feature} to have one of #{expected_release_states} release state," \
              "but got #{metadata.fetch('release_state', 'no value')}"
        end
      end
    end

    describe 'STABLE_FEATURES' do
      it 'contains the expected stable features' do
        expect(described_class::STABLE_FEATURES).to eq({
          code_generations: 0,
          code_completions: 1,
          duo_chat: 2,
          duo_chat_explain_code: 3,
          duo_chat_write_tests: 4,
          duo_chat_refactor_code: 5,
          duo_chat_fix_code: 6,
          review_merge_request: 15,
          duo_agent_platform: 16,
          duo_agent_platform_agentic_chat: 17,
          review_merge_request_dap: 21,
          secret_vulnerability_fp_detection: 19
        }.freeze)
      end

      include_examples 'feature metadata validation', described_class::STABLE_FEATURES, %w[GA]
    end

    describe 'FLAGGED_FEATURES' do
      it 'contains the expected flagged features' do
        expect(described_class::FLAGGED_FEATURES).to eq({
          duo_chat_troubleshoot_job: 7,
          generate_commit_message: 8,
          summarize_new_merge_request: 9,
          duo_chat_explain_vulnerability: 10,
          resolve_vulnerability: 11,
          summarize_review: 12,
          glab_ask_git_command: 13,
          duo_chat_summarize_comments: 14,
          sast_vulnerability_fp_detection: 18,
          sast_vulnerability_resolution: 20,
          security_review: 22,
          embeddings_code: 23,
          feature_discovery_search: 24,
          resolve_dependency_bump: 25
        }.freeze)
      end

      include_examples 'feature metadata validation', described_class::FLAGGED_FEATURES, %w[BETA EXPERIMENT]
    end

    describe 'feature metadata completeness' do
      # certain features are added in feature_metadata.yml for use in
      # model switching, and they may not be available in self-hosted Duo yet.
      let(:features_only_for_model_switching) { %w[] }

      it 'includes all features defined in feature_metadata.yml', :aggregate_failures do
        metadata_features = ::Ai::FeatureConfigurable::FEATURE_METADATA.keys
        features_in_code = described_class::FEATURES.keys.map(&:to_s)

        metadata_features.each do |feature|
          next if features_only_for_model_switching.include?(feature)

          expect(features_in_code).to include(feature),
            "Feature '#{feature}' is defined in feature_metadata.yml " \
              "but missing from STABLE_FEATURES or FLAGGED_FEATURES constants"
        end
      end

      it 'does not allow features that are allowed for self-hosted duo ' \
        'to exist in `features_only_for_model_switching`', :aggregate_failures do
        features_in_code = described_class::FEATURES.keys.map(&:to_s)

        features_in_code.each do |feature|
          expect(features_only_for_model_switching).not_to include(feature),
            "Feature '#{feature}' was previously only available for model switching. " \
              "Now that it is available for Self-Hosted Duo, please remove it " \
              "from the variable `features_only_for_model_switching`"
        end
      end

      it 'has no duplicate feature IDs' do
        feature_ids = described_class::FEATURES.values
        expect(feature_ids).to match_array(feature_ids.uniq),
          "Duplicate feature IDs found: " \
            "#{feature_ids.group_by { |feature_id| feature_id }.select { |_, v| v.size > 1 }.keys}"
      end
    end
  end

  describe '.feature_for_unit_primitive' do
    let_it_be(:feature_setting) do
      create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted)
    end

    context 'when unit primitive does not exist in feature metadata' do
      it 'returns nil' do
        expect(described_class.feature_for_unit_primitive('non_existent_unit_primitive')).to be_nil
      end
    end

    context 'when unit primitive exists in feature metadata' do
      it 'returns the feature' do
        expect(described_class.feature_for_unit_primitive('include_issue_context')).to eq(feature_setting)
      end
    end
  end

  describe '.feature_name_for_unit_primitive' do
    context 'when unit primitive is nil' do
      it 'returns nil' do
        expect(described_class.feature_name_for_unit_primitive(nil)).to be_nil
      end
    end

    context 'when unit primitive does not exist in feature metadata' do
      it 'returns nil' do
        expect(described_class.feature_name_for_unit_primitive('non_existent_unit_primitive')).to be_nil
      end
    end

    context 'when unit primitive exists in feature metadata' do
      it 'returns the mapped feature name when given a string' do
        expect(described_class.feature_name_for_unit_primitive('include_issue_context')).to eq('duo_chat')
      end

      it 'returns the mapped feature name when given a symbol' do
        expect(described_class.feature_name_for_unit_primitive(:include_issue_context)).to eq('duo_chat')
      end
    end
  end

  describe '.unit_primitive_to_feature_name_map' do
    it 'returns the feature' do
      expect(described_class.unit_primitive_to_feature_name_map).to eq(
        {
          "duo_workflow_execute_workflow" => "duo_agent_platform",
          "duo_agent_platform" => "duo_agent_platform",
          "complete_code" => "code_completions",
          "code_suggestions" => "code_completions",
          "generate_code" => "code_generations",
          "duo_chat" => "duo_agent_platform_agentic_chat",
          "duo_classic_chat" => "duo_chat",
          "chat" => "duo_chat",
          "include_file_context" => "duo_chat",
          "include_snippet_context" => "duo_chat",
          "include_merge_request_context" => "duo_chat",
          "include_issue_context" => "duo_chat",
          "include_dependency_context" => "duo_chat",
          "include_local_git_context" => "duo_chat",
          "include_terminal_context" => "duo_chat",
          "include_user_rule_context" => "duo_chat",
          "include_repository_context" => "duo_chat",
          "include_agent_user_environment_context" => "duo_chat",
          "explain_code" => "duo_chat_explain_code",
          "write_tests" => "duo_chat_write_tests",
          "refactor_code" => "duo_chat_refactor_code",
          "fix_code" => "duo_chat_fix_code",
          "troubleshoot_job" => "duo_chat_troubleshoot_job",
          "explain_vulnerability" => "duo_chat_explain_vulnerability",
          "summarize_comments" => "duo_chat_summarize_comments",
          "generate_commit_message" => "generate_commit_message",
          "generate_embeddings_codebase" => "embeddings_code",
          "summarize_new_merge_request" => "summarize_new_merge_request",
          "resolve_vulnerability" => "resolve_vulnerability",
          "summarize_review" => "summarize_review",
          "glab_ask_git_command" => "glab_ask_git_command",
          "review_merge_request" => "review_merge_request",
          "feature_discovery_search" => "feature_discovery_search"
        }
      )
    end
  end

  describe '#user_model_selection_available?' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it 'returns false' do
      expect(feature_setting.user_model_selection_available?).to be false
    end
  end

  describe '#model_allowlist_supported?' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it 'returns false' do
      expect(feature_setting.model_allowlist_supported?).to be false
    end
  end
end
