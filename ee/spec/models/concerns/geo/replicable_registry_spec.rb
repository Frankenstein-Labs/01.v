# frozen_string_literal: true

require 'spec_helper'
# rubocop:disable RSpec/VerifiedDoubles -- Testing against a fake object
RSpec.describe Geo::ReplicableRegistry, feature_category: :geo_replication do
  describe '.oldest_unsynced_time' do
    let(:time_older) { 4.hours.ago }
    let(:time_newer) { 2.hours.ago }

    let(:registry_class) do
      klass = Class.new
      klass.extend(described_class::ClassMethods)
      klass
    end

    before do
      stub_const('Geo::ReplicableRegistry::BATCH_SIZE', 1)
      allow(registry_class).to receive_messages(
        model_foreign_key: :project_id,
        model_updated_last: :updated_at
      )
    end

    # Stubs `unsynced.each_batch` to yield one batch per min_time argument.
    # Each batch stubs `pluck` and `model_updated_scope(...).minimum(...)`.
    def stub_batches(*batch_min_times)
      unsynced_scope = double('unsynced_scope')
      allow(registry_class).to receive(:unsynced).and_return(unsynced_scope)

      allow(unsynced_scope).to receive(:each_batch) do |*_args, **_kwargs, &blk|
        batch_min_times.each_with_index do |min_time, i|
          ids = [i + 1]
          batch = double("batch_#{i}")
          allow(batch).to receive(:pluck).and_return(ids)
          model_scope = double("model_scope_#{i}")
          allow(model_scope).to receive(:minimum).and_return(min_time)
          allow(registry_class).to receive(:model_updated_scope).with(ids).and_return(model_scope)
          blk.call(batch)
        end
      end
    end

    context 'when there are no unsynced records' do
      before do
        unsynced_scope = double('unsynced_scope')
        allow(registry_class).to receive(:unsynced).and_return(unsynced_scope)
        allow(unsynced_scope).to receive(:each_batch)
      end

      it 'returns nil' do
        expect(registry_class.oldest_unsynced_time).to be_nil
      end
    end

    context 'when the second batch has a newer minimum than the first' do
      before do
        stub_batches(time_older, time_newer)
      end

      it 'returns the oldest timestamp from the first batch' do
        expect(registry_class.oldest_unsynced_time).to be_within(1.second).of(time_older)
      end
    end

    context 'when the second batch has an older minimum than the first' do
      before do
        stub_batches(time_newer, time_older)
      end

      it 'returns the oldest timestamp from the second batch' do
        expect(registry_class.oldest_unsynced_time).to be_within(1.second).of(time_older)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
