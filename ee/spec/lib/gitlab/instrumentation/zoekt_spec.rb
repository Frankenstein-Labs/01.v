# frozen_string_literal: true

require 'spec_helper'

# We don't want to interact with Zoekt in GitLab FOSS so we test
# this in ee/ only. The code exists in FOSS and won't do anything.

RSpec.describe ::Gitlab::Instrumentation::Zoekt, :request_store, feature_category: :global_search do
  describe '.increment_request_count' do
    it 'increases the request count by 1' do
      expect { described_class.increment_request_count }.to change { described_class.get_request_count }.by(1)
    end
  end

  describe '.add_duration' do
    it 'increases duration' do
      increase = 1.1
      expect { described_class.add_duration(increase) }.to change { described_class.query_time }.by(increase)
    end

    it 'does not lose precision while adding' do
      precision = 1.0 / (10**::Gitlab::InstrumentationHelper::DURATION_PRECISION)
      2.times { described_class.add_duration(0.4 * precision) }

      # 2 * 0.4 should be 0.8 and get rounded to 1
      expect(described_class.query_time).to eq(1 * precision)
    end
  end

  describe '.add_graphql_duration' do
    context 'when ZOEKT_GRAPHQL_DURATION is already set' do
      before do
        described_class.add_graphql_duration(10)
      end

      it 'adds on existing duration' do
        described_class.add_graphql_duration(5)
        expect(::Gitlab::SafeRequestStore[described_class::ZOEKT_GRAPHQL_DURATION]).to eq 15
      end
    end

    context 'when ZOEKT_GRAPHQL_DURATION is empty' do
      it 'sets the duration' do
        increase = 5
        described_class.add_graphql_duration(increase)
        expect(::Gitlab::SafeRequestStore[described_class::ZOEKT_GRAPHQL_DURATION]).to eq 5
      end
    end
  end

  describe '.zoekt_call_duration' do
    context 'when ZOEKT_CALL_DURATION is set' do
      before do
        described_class.add_duration(10)
      end

      it 'returns the value stored in ZOEKT_CALL_DURATION' do
        expect(described_class.zoekt_call_duration).to eq 10
      end
    end

    context 'when ZOEKT_CALL_DURATION is empty' do
      it 'returns 0' do
        expect(described_class.zoekt_call_duration).to eq 0
      end
    end
  end

  describe '.query_time' do
    before do
      described_class.add_duration(10)
    end

    context 'when ZOEKT_GRAPHQL_DURATION is empty' do
      it 'returns zoekt_call_duration' do
        expect(described_class.query_time).to eq described_class.zoekt_call_duration
      end
    end

    context 'when ZOEKT_GRAPHQL_DURATION is set' do
      before do
        described_class.add_graphql_duration(5)
      end

      it 'returns addition of zoekt_call_duration and graphql_duration' do
        expect(described_class.query_time).to eq described_class.zoekt_call_duration + 5
      end
    end
  end

  describe '.add_call_details' do
    before do
      allow(::Gitlab::PerformanceBar).to receive(:enabled_for_request?).and_return(true)
    end

    it 'adds call details' do
      expect { described_class.add_call_details(duration: 1, method: :GET, path: '/search') }.to change {
        described_class.detail_store.count
      }.by(1)
    end
  end
end
