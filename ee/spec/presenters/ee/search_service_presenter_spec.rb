# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchServicePresenter, feature_category: :global_search do
  describe '#advanced_search_enabled?' do
    let(:user) { build(:user) }

    subject(:presenter) { described_class.new(search_service, current_user: user) }

    context 'when Elasticsearch is enabled' do
      let(:search_service) { instance_double(SearchService, use_elasticsearch?: true) }

      it { is_expected.to be_advanced_search_enabled }
    end

    context 'when Elasticsearch is not enabled' do
      let(:search_service) { instance_double(SearchService, use_elasticsearch?: false) }

      it { is_expected.not_to be_advanced_search_enabled }
    end
  end

  describe '#zoekt_enabled?' do
    let(:user) { build(:user) }

    subject(:presenter) { described_class.new(search_service, current_user: user) }

    context 'when Zoekt is enabled' do
      let(:search_service) { instance_double(SearchService, use_zoekt?: true) }

      it { is_expected.to be_zoekt_enabled }
    end

    context 'when Zoekt is not enabled' do
      let(:search_service) { instance_double(SearchService, use_zoekt?: false) }

      it { is_expected.not_to be_zoekt_enabled }
    end
  end

  describe '#zoekt_language_aggregations_enabled?' do
    let(:user) { build(:user) }
    let(:search_service) { instance_double(SearchService) }

    subject(:presenter) { described_class.new(search_service, current_user: user) }

    it { is_expected.to be_zoekt_language_aggregations_enabled }

    context 'when the zoekt_language_aggregations feature flag is disabled' do
      before do
        stub_feature_flags(zoekt_language_aggregations: false)
      end

      it { is_expected.not_to be_zoekt_language_aggregations_enabled }
    end
  end
end
