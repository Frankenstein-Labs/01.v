# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::RegistryBatcher,
  :use_clean_rails_memory_store_caching,
  feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:source_class) { LfsObject }
  let(:destination_class) { Geo::LfsObjectRegistry }
  let(:destination_class_factory) { registry_factory_name(destination_class) }
  let(:key) { 'looping_batcher_spec' }

  def batcher(batch_size)
    described_class.new(destination_class, key: key, batch_size: batch_size)
  end

  include_examples 'is a Geo batcher'

  # Only Geo registry rows can get into these situations because they cannot have foreign key
  # constraints across databases.
  #
  # As opposed to Verification state backfill, which operates on tables which are stored in the same
  # database.
  describe '#next_range!' do
    let(:source_foreign_key) { batcher(batch_size).send(:source_foreign_key) }
    let(:batch_size) { 2 }

    subject { batcher(batch_size).next_range! }

    context 'when there are no records but there are orphaned destination_records' do
      let!(:destination_records) { create_list(destination_class_factory, 3) }

      before do
        source_class.delete_all
      end

      context 'when it has never been called before' do
        it { is_expected.to be_a Range }

        it 'starts from the beginning' do
          expect(subject.first).to eq(1)
        end

        it 'ends at a full batch' do
          expect(subject.last).to eq(destination_records.second.public_send(source_foreign_key))
        end

        context 'when the batch size is greater than the number of destination_records' do
          let(:batch_size) { 5 }

          it 'ends at the last ID' do
            expect(subject.last).to eq(destination_records.last.public_send(source_foreign_key))
          end
        end
      end

      context 'when it was called before' do
        context 'when the previous batch included the end of the table' do
          before do
            batcher(destination_class.count).next_range!
          end

          it 'starts from the beginning' do
            expect(subject).to eq(1..destination_records.second.public_send(source_foreign_key))
          end
        end

        context 'when the previous batch did not include the end of the table' do
          before do
            batcher(destination_class.count - 1).next_range!
          end

          it 'starts after the previous batch' do
            last_id = destination_records.last.public_send(source_foreign_key)
            expect(subject).to eq(last_id..last_id)
          end
        end

        context 'if cache is cleared' do
          before do
            batcher(batch_size).next_range!
          end

          it 'starts from the beginning' do
            Rails.cache.clear

            expect(subject).to eq(1..destination_records.second.public_send(source_foreign_key))
          end
        end
      end
    end

    context 'when there are records and orphaned destination_records with foreign key greater than last record id' do
      let!(:records) { create_list(factory_name(source_class), 3) }
      let(:orphaned_destination_foreign_key_id) { records.last.id }
      let!(:destination) do
        create(destination_class_factory, source_foreign_key => orphaned_destination_foreign_key_id)
      end

      before do
        source_class.primary_key_in(orphaned_destination_foreign_key_id).delete_all
      end

      context 'when it has never been called before' do
        it { is_expected.to be_a Range }

        it 'ends at a full batch' do
          expect(subject).to eq(1..records.second.id)
        end
      end

      context 'when it was called before' do
        before do
          batcher(batch_size).next_range!
        end

        it 'ends at the last destination foreign key ID' do
          expect(subject).to eq(orphaned_destination_foreign_key_id..orphaned_destination_foreign_key_id)
        end

        context 'if cache is cleared' do
          it 'ends at a full batch' do
            Rails.cache.clear

            expect(subject).to eq(1..records.second.id)
          end
        end
      end
    end
  end
end
