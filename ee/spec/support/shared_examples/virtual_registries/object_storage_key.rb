# frozen_string_literal: true

RSpec.shared_examples 'virtual registries: has object storage key' do |key_prefix:|
  describe '#object_storage_key', :aggregate_failures do
    subject { upstream.object_storage_key }

    it 'contains the expected terms' do
      is_expected.to include(
        "virtual_registries/#{key_prefix}/#{upstream.group_id}/upstream/#{upstream.id}/cache/entry"
      )
    end

    it 'does not return the same value when called twice' do
      first_value = upstream.object_storage_key
      second_value = upstream.object_storage_key

      expect(first_value).not_to eq(second_value)
    end
  end
end
