# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Resolvers::BoardItemFilterable, feature_category: :planning_views do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:epic) { create(:epic, group: group) }

  let(:resolver_class) do
    Class.new do
      include ::BoardItemFilterable

      def initialize(filters)
        @filters = filters
      end

      def test_filter_by_epic
        set_filter_values(@filters)
        @filters
      end
    end
  end

  let(:resolver) { resolver_class.new(filters) }

  describe '#filter_by_epic' do
    context 'when epic_id is provided' do
      let(:filters) { { epic_id: epic.to_gid.to_s } }

      it 'sets include_subepics to true by default' do
        result = resolver.test_filter_by_epic

        expect(result[:epic_id]).to eq(epic.id.to_s)
        expect(result[:include_subepics]).to be(true)
      end
    end

    context 'when epic_id and include_subepics are provided' do
      context 'when include_subepics is true' do
        let(:filters) { { epic_id: epic.to_gid.to_s, include_subepics: true } }

        it 'preserves include_subepics value' do
          result = resolver.test_filter_by_epic

          expect(result[:epic_id]).to eq(epic.id.to_s)
          expect(result[:include_subepics]).to be(true)
        end
      end

      context 'when include_subepics is false' do
        let(:filters) { { epic_id: epic.to_gid.to_s, include_subepics: false } }

        it 'preserves include_subepics value' do
          result = resolver.test_filter_by_epic

          expect(result[:epic_id]).to eq(epic.id.to_s)
          expect(result[:include_subepics]).to be(false)
        end
      end
    end

    context 'when epic_wildcard_id is provided' do
      let(:filters) { { epic_wildcard_id: 'NONE' } }

      it 'does not set include_subepics' do
        result = resolver.test_filter_by_epic

        expect(result[:epic_id]).to eq('NONE')
        expect(result).not_to have_key(:include_subepics)
      end
    end

    context 'when both epic_id and epic_wildcard_id are provided' do
      let(:filters) { { epic_id: epic.to_gid.to_s, epic_wildcard_id: 'NONE' } }

      it 'raises an error' do
        expect { resolver.test_filter_by_epic }.to raise_error(
          ::Gitlab::Graphql::Errors::ArgumentError,
          'Incompatible arguments: epicId, epicWildcardId.'
        )
      end
    end

    context 'when no epic filters are provided' do
      let(:filters) { {} }

      it 'does not modify filters' do
        result = resolver.test_filter_by_epic

        expect(result).to eq({})
      end
    end
  end
end
