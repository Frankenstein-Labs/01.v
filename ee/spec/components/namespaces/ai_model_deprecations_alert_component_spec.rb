# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'renders model deprecation alert for multiple deprecated models' do |expected_models|
  it 'renders a deprecation alert with the correct title' do
    expected_title = n_('Model scheduled for removal', 'Models scheduled for removal', expected_models.count)

    expect(page).to have_selector('[data-testid="ai-model-deprecation-alert"]')
    expect(page).to have_content(expected_title)
  end

  it 'renders the multiple models deprecation message' do
    expect(page).to have_content(
      'The following models have been deprecated and will stop working after GitLab removes them'
    )
  end

  it 'renders a list with all deprecated models' do
    expect(page).to have_selector('ul li', count: expected_models.count)

    expected_models.each do |model|
      expect(page).to have_content(
        "#{model['model_name']} (deprecated on #{model['deprecation_date']} - " \
          "Removal scheduled for: #{model['removal_version']})"
      )
    end
  end
end

RSpec.describe Namespaces::AiModelDeprecationsAlertComponent, :saas, feature_category: :duo_chat do
  include_context 'with mocked ::Ai::ModelSelection::FetchModelDefinitionsService'

  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:subgroup) { build_stubbed(:group, parent: group) }

  subject(:component) { described_class.new(group: group) }

  context 'when on group settings' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when group is a top-level group and user is owner of this group' do
      context 'when a single deprecated model is selected' do
        let_it_be(:namespace_setting) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :review_merge_request,
            offered_model_ref: 'claude-sonnet-3-7',
            model_definitions: fetch_model_definitions_example)
        end

        before do
          allow(::Ai::ModelSelection::NamespaceFeatureSetting)
            .to receive_message_chain(:for_namespace, :non_default)
            .and_return([namespace_setting])

          render_inline(component)
        end

        include_examples 'renders model deprecation alert for multiple deprecated models', [
          { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' }
        ]

        it 'renders the change model button' do
          expect(page).to have_link('Change model', href: group_settings_gitlab_duo_model_selection_index_path(group))
        end
      end

      context 'when multiple deprecated models are selected' do
        let_it_be(:model_definitions_with_multiple_deprecated) do
          fetch_model_definitions_example.merge(
            'models' => fetch_model_definitions_example['models'] + [
              { 'name' => 'GPT-4 Deprecated', 'identifier' => 'gpt-4-deprecated',
                'deprecation' => { 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' } }
            ]
          )
        end

        let_it_be(:namespace_setting_1) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :review_merge_request,
            offered_model_ref: 'claude-sonnet-3-7',
            model_definitions: model_definitions_with_multiple_deprecated)
        end

        let_it_be(:namespace_setting_2) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_chat,
            offered_model_ref: 'gpt-4-deprecated',
            model_definitions: model_definitions_with_multiple_deprecated)
        end

        before do
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: model_definitions_with_multiple_deprecated)
            )
          end

          allow(::Ai::ModelSelection::NamespaceFeatureSetting)
            .to receive_message_chain(:for_namespace, :non_default)
            .and_return([namespace_setting_1, namespace_setting_2])

          render_inline(component)
        end

        include_examples 'renders model deprecation alert for multiple deprecated models', [
          { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' },
          { 'model_name' => 'GPT-4 Deprecated', 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' }
        ]

        it 'renders the change model button' do
          expect(page).to have_link('Change model', href: group_settings_gitlab_duo_model_selection_index_path(group))
        end
      end

      context 'when a model is deprecated for the pinned feature only' do
        let_it_be(:model_definitions_with_feature_deprecated_model) do
          fetch_model_definitions_example.deep_dup.tap do |definitions|
            definitions['unit_primitives'].find { |up| up['feature_setting'] == 'code_completions' }
              .merge!('deprecated_models' => [
                { 'identifier' => 'gpt-4', 'deprecation_date' => '2026-08-05', 'removal_version' => '19.6' }
              ])
          end
        end

        let_it_be(:namespace_setting_feature_deprecated) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :code_completions,
            offered_model_ref: 'gpt-4',
            model_definitions: model_definitions_with_feature_deprecated_model)
        end

        let_it_be(:namespace_setting_unaffected) do
          build_stubbed(:ai_namespace_feature_setting,
            namespace: group,
            feature: :duo_chat,
            offered_model_ref: 'gpt-4',
            model_definitions: model_definitions_with_feature_deprecated_model)
        end

        before do
          allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.success(payload: model_definitions_with_feature_deprecated_model)
            )
          end

          allow(::Ai::ModelSelection::NamespaceFeatureSetting)
            .to receive_message_chain(:for_namespace, :non_default)
            .and_return([namespace_setting_feature_deprecated, namespace_setting_unaffected])

          render_inline(component)
        end

        it 'renders the alert naming the affected feature', :aggregate_failures do
          expect(page).to have_content('Model scheduled for removal')
          expect(page).to have_selector('ul li', count: 1)
          expect(page).to have_content(
            'GPT-4 (deprecated for Code Completion on 2026-08-05 - Removal scheduled for: 19.6)'
          )
          expect(page).to have_selector('ul li strong', text: 'Code Completion')
        end
      end
    end

    context 'when a no deprecated model is selected' do
      let_it_be(:namespace_setting) do
        build_stubbed(:ai_namespace_feature_setting,
          namespace: group,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::NamespaceFeatureSetting)
          .to receive_message_chain(:for_namespace, :non_default)
          .and_return([namespace_setting])

        render_inline(component)
      end

      it 'does not render the deprecation alert' do
        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end

    context 'when user is not an owner of the group' do
      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end

    context 'when group is not a top-level group' do
      subject(:component) { described_class.new(group: subgroup) }

      it 'does not render the deprecation alert' do
        render_inline(component)

        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end
  end

  context 'when on instance settings' do
    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    context 'when a single deprecated model is selected' do
      let_it_be(:instance_setting) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting])

        render_inline(component)
      end

      include_examples 'renders model deprecation alert for multiple deprecated models', [
        { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' }
      ]

      it 'renders the change model button' do
        expect(page).to have_link('Change model', href: admin_gitlab_duo_model_selection_index_path)
      end
    end

    context 'when multiple deprecated models are selected' do
      let_it_be(:model_definitions_with_multiple_deprecated) do
        fetch_model_definitions_example.merge(
          'models' => fetch_model_definitions_example['models'] + [
            { 'name' => 'GPT-4 Deprecated', 'identifier' => 'gpt-4-deprecated',
              'deprecation' => { 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' } }
          ]
        )
      end

      let_it_be(:instance_setting_1) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: model_definitions_with_multiple_deprecated)
      end

      let_it_be(:instance_setting_2) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :duo_chat,
          offered_model_ref: 'gpt-4-deprecated',
          model_definitions: model_definitions_with_multiple_deprecated)
      end

      before do
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: model_definitions_with_multiple_deprecated)
          )
        end

        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting_1, instance_setting_2])

        render_inline(component)
      end

      include_examples 'renders model deprecation alert for multiple deprecated models', [
        { 'model_name' => 'Claude Sonnet 3.7', 'deprecation_date' => '2025-10-28', 'removal_version' => '18.8' },
        { 'model_name' => 'GPT-4 Deprecated', 'deprecation_date' => '2025-11-15', 'removal_version' => '18.9' }
      ]

      it 'renders the change model button' do
        expect(page).to have_link('Change model', href: admin_gitlab_duo_model_selection_index_path)
      end
    end

    context 'when a no deprecated model is selected' do
      let_it_be(:instance_setting) do
        build_stubbed(:instance_model_selection_feature_setting,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet',
          model_definitions: fetch_model_definitions_example)
      end

      before do
        allow(::Ai::ModelSelection::InstanceModelSelectionFeatureSetting)
          .to receive(:non_default)
          .and_return([instance_setting])

        render_inline(component)
      end

      it 'does not render the deprecation alert' do
        expect(page).not_to have_selector('[data-testid="ai-model-deprecation-alert"]')
      end
    end
  end

  describe '#selected_deprecated_models' do
    subject(:selected_deprecated_models) { component.send(:selected_deprecated_models) }

    context 'when deprecated_models_by_id is empty' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: { 'models' => [] })
          )
        end
      end

      let_it_be(:namespace_setting) do
        build_stubbed(:ai_namespace_feature_setting,
          namespace: group,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: fetch_model_definitions_example)
      end

      it 'returns empty array without errors' do
        allow(::Ai::ModelSelection::NamespaceFeatureSetting)
          .to receive_message_chain(:for_namespace, :non_default)
          .and_return([namespace_setting])

        expect(selected_deprecated_models).to eq([])
      end
    end

    context 'when deprecated_models is nil' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(component).to receive(:deprecated_models).and_return(nil)
      end

      let_it_be(:namespace_setting) do
        build_stubbed(:ai_namespace_feature_setting,
          namespace: group,
          feature: :review_merge_request,
          offered_model_ref: 'claude-sonnet-3-7',
          model_definitions: fetch_model_definitions_example)
      end

      it 'returns empty array without raising an error' do
        allow(::Ai::ModelSelection::NamespaceFeatureSetting)
          .to receive_message_chain(:for_namespace, :non_default)
          .and_return([namespace_setting])

        expect(selected_deprecated_models).to eq([])
      end
    end
  end

  describe '#deprecated_models' do
    subject(:deprecated_models) { component.send(:deprecated_models) }

    it 'returns empty array when service succeeds with a nil payload' do
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: nil)
        )
      end

      expect(deprecated_models).to eq([])
    end

    it 'returns deprecated models when service succeeds', :aggregate_failures do
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: fetch_model_definitions_example)
        )
      end

      result = deprecated_models

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first['identifier']).to eq('claude-sonnet-3-7')
      expect(result.first['name']).to eq('Claude Sonnet 3.7')
      expect(result.first['deprecation']).to include('deprecation_date' => '2025-10-28', 'removal_version' => '18.8')
    end

    it 'returns empty array when service fails' do
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Failed to fetch models')
        )
      end

      expect(deprecated_models).to eq([])
    end

    it 'returns empty array when service returns nil' do
      allow_next_instance_of(::Ai::ModelSelection::FetchModelDefinitionsService) do |service|
        allow(service).to receive(:execute).and_return(nil)
      end

      expect(deprecated_models).to eq([])
    end
  end
end
