# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::UserModelSelection, :saas, feature_category: :duo_agent_platform do
  include_context 'with model selections fetch definition service side-effect context'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:feature) { :duo_agent_platform_agentic_chat }
  let(:offered_model_ref) { '' }
  let(:model_allowlist_enabled) { false }
  let(:model_allowlist_gitlab_model_refs) { [] }

  subject(:user_model_selection) do
    described_class.new(user, feature_setting: feature_setting)
  end

  before do
    allow(user).to receive(:governing_namespace).and_return(group)
  end

  describe '.for' do
    subject(:selection) { described_class.for(user, feature_setting: feature_setting) }

    context 'when the feature setting points to a self-hosted model' do
      let(:feature_setting) do
        build(:ai_feature_setting, feature: feature, self_hosted_model: build(:ai_self_hosted_model))
      end

      it 'returns a self-hosted selection' do
        expect(selection).to be_a(Ai::ModelSelection::SelfHostedModelSelection)
      end
    end

    context 'when the feature setting is cloud-connected' do
      let(:feature_setting) do
        build(:ai_namespace_feature_setting, namespace: group, feature: feature)
      end

      it 'returns a cloud selection' do
        expect(selection).to be_an_instance_of(described_class)
      end
    end

    context 'when no feature setting is given' do
      let(:feature_setting) { nil }

      it 'returns a cloud selection' do
        expect(selection).to be_an_instance_of(described_class)
      end
    end
  end

  # The class is scope-agnostic: it behaves identically for namespace-scoped settings
  # (gitlab.com / cloud-connected namespace) and instance-scoped settings (cloud-connected
  # self-managed). Both flow through the metadata service.
  shared_examples 'resolves the user-visible model picture' do
    before do
      stub_request(:get, fetch_service_endpoint_url)
        .to_return(status: 200, body: model_definitions_response, headers: { 'Content-Type' => 'application/json' })
    end

    describe '#default_model' do
      it 'returns the default model for the feature' do
        expect(user_model_selection.default_model[:ref]).to eq('claude_sonnet_4_20250514')
      end

      context 'when the admin allowlist is enabled' do
        let(:model_allowlist_enabled) { true }

        context 'when the admin has chosen a model' do
          let(:offered_model_ref) { 'claude_sonnet_3_7' }

          it 'returns the chosen model as the default' do
            expect(user_model_selection.default_model[:ref]).to eq('claude_sonnet_3_7')
          end
        end

        context 'when the admin has not chosen a model' do
          it 'returns the GitLab default model' do
            expect(user_model_selection.default_model[:ref]).to eq('claude_sonnet_4_20250514')
          end
        end
      end
    end

    describe '#selectable_models' do
      it 'returns the full set of selectable models' do
        expect(user_model_selection.selectable_models.map { |model| model[:ref] })
          .to match_array(%w[claude_sonnet_4_20250514 claude_sonnet_3_7])
      end

      context 'when the admin allowlist is enabled' do
        let(:model_allowlist_enabled) { true }
        let(:model_allowlist_gitlab_model_refs) { %w[claude_sonnet_3_7] }
        let(:offered_model_ref) { 'claude_sonnet_3_7' }

        it 'narrows the selectable models to the allowlist' do
          expect(user_model_selection.selectable_models.map { |model| model[:ref] })
            .to contain_exactly('claude_sonnet_3_7')
        end

        context 'when the admin has chosen a model outside the allowlist' do
          let(:offered_model_ref) { 'claude_sonnet_4_20250514' }

          it 'always includes the chosen model' do
            expect(user_model_selection.selectable_models.map { |model| model[:ref] })
              .to match_array(%w[claude_sonnet_4_20250514 claude_sonnet_3_7])
          end
        end
      end
    end

    describe '#pinned_model' do
      context 'when a model is pinned' do
        let(:offered_model_ref) { 'claude_sonnet_4_20250514' }

        it 'returns the pinned model' do
          expect(user_model_selection.pinned_model[:ref]).to eq('claude_sonnet_4_20250514')
        end
      end

      context 'when no model is pinned' do
        it 'returns nil' do
          expect(user_model_selection.pinned_model).to be_nil
        end
      end

      context 'when the admin allowlist is enabled' do
        let(:model_allowlist_enabled) { true }
        let(:offered_model_ref) { 'claude_sonnet_4_20250514' }

        it 'returns nil so the model can still be selected' do
          expect(user_model_selection.pinned_model).to be_nil
        end

        context 'when the admin has not chosen a model' do
          let(:offered_model_ref) { '' }

          it 'returns nil' do
            expect(user_model_selection.pinned_model).to be_nil
          end
        end
      end
    end

    describe '#do_not_consider_user_selected_model?' do
      it 'considers a selectable ref' do
        expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(false)
      end

      it 'ignores a non-selectable ref' do
        expect(user_model_selection.do_not_consider_user_selected_model?('openai_chatgpt_4o')).to be(true)
      end

      it 'ignores a blank ref' do
        expect(user_model_selection.do_not_consider_user_selected_model?('')).to be(true)
      end

      context 'when a model is pinned' do
        let(:offered_model_ref) { 'claude_sonnet_4_20250514' }

        it 'ignores an otherwise selectable ref' do
          expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
        end
      end

      context 'when the feature is not agentic chat' do
        let(:feature) { :duo_chat }

        it 'ignores a selectable ref' do
          expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
        end
      end

      context 'when the admin allowlist is enabled' do
        let(:model_allowlist_enabled) { true }
        let(:model_allowlist_gitlab_model_refs) { %w[claude_sonnet_3_7] }

        context 'when the admin has chosen a model' do
          let(:offered_model_ref) { 'claude_sonnet_4_20250514' }

          it 'considers an allowlisted ref instead of treating the choice as pinned' do
            expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(false)
          end
        end

        context 'when the ref is selectable but excluded from the allowlist' do
          let(:offered_model_ref) { 'claude_sonnet_3_7' }

          it 'ignores it' do
            expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_4_20250514')).to be(true)
          end
        end

        context 'when the admin has not chosen a model' do
          let(:offered_model_ref) { '' }

          it 'considers an allowlisted ref' do
            expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(false)
          end

          it 'ignores a ref outside the allowlist' do
            expect(user_model_selection.do_not_consider_user_selected_model?('openai_chatgpt_4o')).to be(true)
          end
        end
      end
    end

    context 'when the feature is absent from the definitions' do
      let(:model_definitions) do
        {
          'models' => [{ 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' }],
          'unit_primitives' => [
            {
              'feature_setting' => 'duo_chat',
              'default_model' => 'claude_sonnet_3_5',
              'selectable_models' => %w[claude_sonnet_3_5],
              'beta_models' => []
            }
          ]
        }
      end

      it 'returns empty results', :aggregate_failures do
        expect(user_model_selection.default_model).to be_nil
        expect(user_model_selection.selectable_models).to eq([])
        expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
      end
    end
  end

  context 'with a namespace feature setting' do
    let(:feature_setting) do
      create(:ai_namespace_feature_setting,
        namespace: group, feature: feature, offered_model_ref: offered_model_ref, model_definitions: model_definitions,
        model_allowlist_enabled: model_allowlist_enabled,
        model_allowlist_gitlab_model_refs: model_allowlist_gitlab_model_refs)
    end

    it_behaves_like 'resolves the user-visible model picture'
  end

  context 'with an instance feature setting' do
    let(:feature_setting) do
      create(:instance_model_selection_feature_setting,
        feature: feature, offered_model_ref: offered_model_ref, model_definitions: model_definitions,
        model_allowlist_enabled: model_allowlist_enabled,
        model_allowlist_gitlab_model_refs: model_allowlist_gitlab_model_refs)
    end

    it_behaves_like 'resolves the user-visible model picture'
  end

  context 'when no feature setting is given' do
    let(:feature_setting) { nil }

    it 'returns empty results without fetching definitions', :aggregate_failures do
      expect(::Ai::ModelSelection::FetchModelDefinitionsService).not_to receive(:new)

      expect(user_model_selection.default_model).to be_nil
      expect(user_model_selection.selectable_models).to eq([])
      expect(user_model_selection.pinned_model).to be_nil
      expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
    end
  end

  context 'when the fetch fails' do
    let(:feature_setting) do
      create(:ai_namespace_feature_setting, namespace: group, feature: feature, offered_model_ref: offered_model_ref)
    end

    before do
      stub_request(:get, fetch_service_endpoint_url)
        .to_return(status: 400, body: '{}', headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns empty results', :aggregate_failures do
      expect(user_model_selection.default_model).to be_nil
      expect(user_model_selection.selectable_models).to eq([])
      expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
    end
  end

  context 'when the fetch returns nil' do
    let(:feature_setting) do
      create(:ai_namespace_feature_setting, namespace: group, feature: feature, offered_model_ref: offered_model_ref)
    end

    before do
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(nil)
      end
    end

    it 'returns empty results', :aggregate_failures do
      expect(user_model_selection.default_model).to be_nil
      expect(user_model_selection.selectable_models).to eq([])
      expect(user_model_selection.do_not_consider_user_selected_model?('claude_sonnet_3_7')).to be(true)
    end
  end
end
