# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Delete::GroupsService, :elastic_helpers, feature_category: :global_search do
  let_it_be(:old_root_group) { create(:group) }
  let_it_be(:new_root_group) { create(:group) }
  let_it_be(:group) { create(:group, parent: old_root_group) }
  let_it_be(:subgroup) { create(:group, parent: group) }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
  end

  describe '#index_name' do
    it 'returns the group index name' do
      service = described_class.new({})

      expect(service.send(:index_name)).to eq(::Search::Elastic::Types::Group.index_name)
    end
  end

  describe '#execute' do
    let(:client) { instance_double(::Gitlab::Search::Client) }

    before do
      allow(::Gitlab::Search::Client).to receive(:new).and_return(client)
    end

    context 'when group_ids and ancestor_id are provided' do
      it 'deletes the groups with the specified routing' do
        expect(client).to receive(:delete_by_query).with(
          hash_including(
            index: ::Search::Elastic::Types::Group.index_name,
            routing: "group_#{old_root_group.id}",
            body: {
              query: {
                bool: {
                  filter: { terms: { id: [group.id] } }
                }
              }
            }
          )
        ).and_return({ 'deleted' => 1 })

        described_class.execute({
          group_ids: [group.id],
          ancestor_id: old_root_group.id
        })
      end
    end

    context 'when multiple group_ids are provided' do
      it 'deletes all specified groups' do
        group_ids = [group.id, subgroup.id]

        expect(client).to receive(:delete_by_query).with(
          hash_including(
            index: ::Search::Elastic::Types::Group.index_name,
            routing: "group_#{old_root_group.id}",
            body: {
              query: {
                bool: {
                  filter: { terms: { id: group_ids } }
                }
              }
            }
          )
        ).and_return({ 'deleted' => 2 })

        described_class.execute({
          group_ids: group_ids,
          ancestor_id: old_root_group.id
        })
      end
    end

    context 'when group_ids is missing' do
      it 'tracks an error and returns early' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          instance_of(ArgumentError)
        )
        expect(client).not_to receive(:delete_by_query)

        described_class.execute({
          ancestor_id: old_root_group.id
        })
      end
    end

    context 'when ancestor_id is missing' do
      it 'tracks an error and returns early' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          instance_of(ArgumentError)
        )
        expect(client).not_to receive(:delete_by_query)

        described_class.execute({
          group_ids: [group.id]
        })
      end
    end

    context 'when Groups index is not defined' do
      it 'returns early without deleting' do
        hide_const('Search::Elastic::Types::Group')

        expect(client).not_to receive(:delete_by_query)

        described_class.execute({
          group_ids: [group.id],
          ancestor_id: old_root_group.id
        })
      end
    end
  end
end
