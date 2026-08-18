# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FeatureLibrary::FeatureMatchService, feature_category: :onboarding do
  let_it_be(:user) { build(:user) }
  let_it_be(:group) { build(:group, developers: user) }

  let(:query) { 'review code' }
  let(:panel) { 'group' }
  let(:resource) { group }
  let(:catalog) do
    [{ id: 'group_merge_request_list', name: 'Merge requests', description: 'Review merge requests' }]
  end

  let(:completion_class) { ::Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch }

  subject(:service) do
    described_class.new(query: query, panel: panel, user: user, resource: resource)
  end

  before do
    allow(Onboarding::FeatureLibrary::TerminologyMap).to receive(:all).and_return(
      [{ 'term' => 'pipeline', 'feature_key' => 'pipelines', 'panels' => %w[project group] }]
    )
  end

  describe '#ai_execute' do
    subject(:result) { service.ai_execute }

    context 'when eligible' do
      before do
        stub_feature_flags(feature_discovery_gemini_search: user)
        allow(group).to receive(:trial_active?).and_return(true)
        allow_next_instance_of(Onboarding::FeatureLibrary::CatalogBuilder) do |builder|
          allow(builder).to receive(:execute).and_return(catalog)
        end
      end

      it 'sends the query plus catalog to Gemini and returns the matched ids' do
        expect_next_instance_of(
          completion_class,
          an_instance_of(::Gitlab::Llm::AiMessage),
          nil,
          a_hash_including(action: :feature_discovery_search, query: query, catalog: catalog)
        ) do |completion|
          expect(completion).to receive(:execute).and_return(%w[group_merge_request_list])
        end

        expect(result).to eq(%w[group_merge_request_list])
      end

      context 'when the catalog is empty' do
        let(:catalog) { [] }

        it 'returns [] without calling the AI Gateway' do
          expect(completion_class).not_to receive(:new)
          expect(result).to eq([])
        end
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(feature_discovery_gemini_search: false)
      end

      it 'returns [] without calling the AI Gateway' do
        expect(completion_class).not_to receive(:new)
        expect(result).to eq([])
      end
    end

    context 'when the namespace is not on an active trial' do
      before do
        stub_feature_flags(feature_discovery_gemini_search: user)
        allow(group).to receive(:trial_active?).and_return(false)
      end

      it 'returns [] without calling the AI Gateway' do
        expect(completion_class).not_to receive(:new)
        expect(result).to eq([])
      end
    end

    context 'without a resource' do
      let(:resource) { nil }

      before do
        stub_feature_flags(feature_discovery_gemini_search: user)
      end

      it 'returns [] without calling the AI Gateway' do
        expect(completion_class).not_to receive(:new)
        expect(result).to eq([])
      end
    end
  end

  describe 'search resolution tracking' do
    let_it_be(:tracking_user) { create(:user) }
    let_it_be(:tracking_group) { create(:group) }

    let(:panel) { 'group' }
    let(:tracked_service) do
      described_class.new(query: query, panel: panel, user: tracking_user, resource: tracking_group)
    end

    before do
      stub_feature_flags(feature_discovery_gemini_search: false)
    end

    shared_examples 'does not track the search' do
      context 'without a user' do
        let(:tracked_service) do
          described_class.new(query: query, panel: panel, user: nil, resource: tracking_group)
        end

        it 'does not emit a resolution event' do
          expect { perform_search }
            .not_to trigger_internal_events('resolve_feature_discovery_search')
        end
      end

      context 'with an invalid panel' do
        let(:panel) { 'invalid_panel' }

        it 'does not emit a resolution event' do
          expect { perform_search }
            .not_to trigger_internal_events('resolve_feature_discovery_search')
        end
      end
    end

    describe '#execute' do
      context 'when Tier 1 resolves the query' do
        let(:query) { 'pipeline' }

        it 'emits an exact_map resolution event' do
          expect { tracked_service.execute }
            .to trigger_internal_events('resolve_feature_discovery_search').with(
              user: tracking_user,
              namespace: tracking_group,
              additional_properties: {
                label: 'exact_map',
                value: an_instance_of(Integer)
              }
            )
        end
      end

      context 'when Tier 2 resolves the query' do
        let(:query) { 'set up a pipeline' }

        it 'emits a keyword_extract resolution event' do
          expect { tracked_service.execute }
            .to trigger_internal_events('resolve_feature_discovery_search').with(
              user: tracking_user,
              namespace: tracking_group,
              additional_properties: {
                label: 'keyword_extract',
                value: an_instance_of(Integer)
              }
            )
        end
      end

      context 'when no tier resolves the query' do
        let(:query) { 'completelyrandom' }

        it 'emits a no_match resolution event' do
          expect { tracked_service.execute }
            .to trigger_internal_events('resolve_feature_discovery_search').with(
              user: tracking_user,
              namespace: tracking_group,
              additional_properties: {
                label: 'no_match',
                value: an_instance_of(Integer)
              }
            )
        end
      end

      it_behaves_like 'does not track the search' do
        let(:perform_search) { tracked_service.execute }
      end
    end

    describe '#ai_execute' do
      let(:query) { 'completelyrandom' }
      let(:tracked_catalogue) do
        [{ id: 'group_merge_request_list', name: 'Merge requests', description: 'Review merge requests' }]
      end

      before do
        stub_feature_flags(feature_discovery_gemini_search: tracking_user)
        allow(tracking_group).to receive(:trial_active?).and_return(true)
        allow_next_instance_of(Onboarding::FeatureLibrary::CatalogBuilder) do |builder|
          allow(builder).to receive(:execute).and_return(tracked_catalogue)
        end
      end

      context 'when Gemini resolves the query' do
        before do
          allow_next_instance_of(completion_class) do |completion|
            allow(completion).to receive(:execute).and_return(%w[group_merge_request_list])
          end
        end

        it 'emits a gemini resolution event' do
          expect { tracked_service.ai_execute }
            .to trigger_internal_events('resolve_feature_discovery_search').with(
              user: tracking_user,
              namespace: tracking_group,
              additional_properties: {
                label: 'gemini',
                value: an_instance_of(Integer)
              }
            )
        end
      end

      context 'when Gemini returns no matches' do
        before do
          allow_next_instance_of(completion_class) do |completion|
            allow(completion).to receive(:execute).and_return([])
          end
        end

        it 'emits a no_gemini_match resolution event' do
          expect { tracked_service.ai_execute }
            .to trigger_internal_events('resolve_feature_discovery_search').with(
              user: tracking_user,
              namespace: tracking_group,
              additional_properties: {
                label: 'no_gemini_match',
                value: an_instance_of(Integer)
              }
            )
        end
      end

      it_behaves_like 'does not track the search' do
        let(:perform_search) { tracked_service.ai_execute }
      end
    end
  end

  describe '#ai_search_available?' do
    before do
      stub_feature_flags(feature_discovery_gemini_search: user)
      allow(group).to receive(:trial_active?).and_return(true)
    end

    subject(:available) do
      described_class.new(query: query, panel: panel, user: user, resource: resource).ai_search_available?
    end

    it { is_expected.to be(true) }

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(feature_discovery_gemini_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the namespace is not on an active trial' do
      before do
        allow(group).to receive(:trial_active?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'without a resource' do
      let(:resource) { nil }

      it { is_expected.to be(false) }
    end

    context 'when root_ancestor is nil' do
      before do
        allow(group).to receive(:root_ancestor).and_return(nil)
      end

      it { is_expected.to be(false) }
    end
  end
end
