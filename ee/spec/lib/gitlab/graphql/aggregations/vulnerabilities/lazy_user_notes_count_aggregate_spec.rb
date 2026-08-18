# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::Vulnerabilities::LazyUserNotesCountAggregate, feature_category: :vulnerability_management do
  let(:query_ctx) do
    {}
  end

  let(:state_key) { lazy_aggregate.state_key }

  let(:vulnerability) { create(:vulnerability) }

  subject(:lazy_aggregate) { described_class.new(query_ctx, vulnerability) }

  describe '#initialize' do
    it 'adds the vulnerability to the lazy state' do
      expect(lazy_aggregate.lazy_state[:pending_vulnerability_ids]).to match [vulnerability.id]
      expect(lazy_aggregate.vulnerability).to match vulnerability
    end

    context 'when there are existing pending_vulnerability_ids' do
      subject(:result) do
        described_class.new(
          { state_key => {
            pending_vulnerability_ids: pending_ids_set,
            loaded_objects: {}
          } },
          vulnerability
        )
      end

      let(:pending_ids_set) { [10, 20, 30].to_set }
      let(:expected_ids) { pending_ids_set.dup.add(vulnerability.id) }

      it 'uses state_key to collect aggregates' do
        expect(result.lazy_state[:pending_vulnerability_ids]).to match_array expected_ids
        expect(result.vulnerability).to match vulnerability
      end
    end
  end

  describe '#execute' do
    before do
      lazy_aggregate.instance_variable_set(:@lazy_state, fake_state)
    end

    context 'if the record has already been loaded' do
      let(:fake_state) do
        { pending_vulnerability_ids: Set.new, loaded_objects: { vulnerability.id => 10 } }
      end

      it 'does not make the query again' do
        expect(::Note).not_to receive(:user)

        lazy_aggregate.execute
      end
    end

    context 'if the record has not been loaded' do
      let(:other_vulnerability) { create(:vulnerability) }
      let(:fake_state) do
        { pending_vulnerability_ids: Set.new([vulnerability.id, other_vulnerability.id]), loaded_objects: {} }
      end

      let(:fake_data) do
        {
          vulnerability.id => 10,
          other_vulnerability.id => 14
        }
      end

      before do
        allow(::Note).to receive_message_chain(:user, :count_for_vulnerability_id).and_return(fake_data)
      end

      it 'makes the query' do
        expect(::Note).to receive_message_chain(:user, :count_for_vulnerability_id).with([vulnerability.id, other_vulnerability.id])

        lazy_aggregate.execute
      end

      it 'clears the pending IDs' do
        lazy_aggregate.execute

        expect(lazy_aggregate.lazy_state[:pending_vulnerability_ids]).to be_empty
      end
    end
  end
end
