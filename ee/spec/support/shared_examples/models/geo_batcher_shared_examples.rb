# frozen_string_literal: true

# Requires the caller to define a method `def batcher(batch_size)` which returns
# an instance of the described class.
RSpec.shared_examples 'is a Geo batcher' do
  include EE::GeoHelpers

  describe '#next_range!' do
    let(:source_foreign_key) { batcher(batch_size).send(:source_foreign_key) }
    let(:batch_size) { 2 }

    subject { batcher(batch_size).next_range! }

    context 'when there are no records' do
      it { is_expected.to be_nil }
    end

    context 'when there are records' do
      let!(:records) { create_list(factory_name(source_class), 3) }

      context 'when it has never been called before' do
        it { is_expected.to be_a Range }

        it 'starts from the beginning' do
          expect(subject.first).to eq(1)
        end

        it 'ends at a full batch' do
          expect(subject.last).to eq(records.second.id)
        end

        context 'when the batch size is greater than the number of records' do
          let(:batch_size) { 5 }

          it 'ends at the last ID' do
            expect(subject.last).to eq(records.last.id)
          end
        end

        context 'when the destination table has a gap of at least one batch' do
          let(:batch_size) { 1 }
          let!(:destination_records) do
            create(destination_class_factory, source_query_constraints(records.last))
          end

          it 'returns a batch ending at batch size' do
            expect(subject).to eq(1..source_class.first.id)
          end

          def source_query_constraints(record)
            attrs = { source_foreign_key => record.id }
            return attrs unless record.attributes.key?("partition_id")

            attrs.merge({ "partition_id" => record.partition_id })
          end
        end
      end

      context 'when it was called before' do
        context 'when the previous batch included the end of the table' do
          before do
            batcher(source_class.count).next_range!
          end

          it 'starts from the beginning' do
            expect(subject).to eq(1..records.second.id)
          end
        end

        context 'when the previous batch did not include the end of the table' do
          before do
            batcher(source_class.count - 1).next_range!
          end

          it 'starts after the previous batch' do
            expect(subject).to eq(records.last.id..records.last.id)
          end
        end

        context 'if cache is cleared' do
          before do
            batcher(batch_size).next_range!
          end

          it 'starts from the beginning' do
            Rails.cache.clear

            expect(subject).to eq(1..records.second.id)
          end
        end
      end
    end
  end
end
