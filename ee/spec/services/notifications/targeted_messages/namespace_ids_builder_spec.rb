# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessages::NamespaceIdsBuilder, feature_category: :acquisition do
  describe '#build' do
    subject(:result) { described_class.new(csv_file).build }

    let_it_be(:valid_namespace_ids) { create_list(:namespace, 2).map(&:id) }
    let(:invalid_namespace_ids) { [non_existing_record_id] }
    let(:csv_content) { (valid_namespace_ids + invalid_namespace_ids).map(&:to_s).join("\n") }
    let(:temp_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      temp_file
    end

    let(:csv_file) { fixture_file_upload(temp_file.path, 'text/csv') }

    after do
      temp_file.unlink
    end

    context 'with valid CSV data' do
      it 'returns valid, invalid namespace ids and warning message about invalid ids' do
        expect(result[:success]).to be(true)
        expect(result[:valid_namespace_ids]).to match_array(valid_namespace_ids)
        expect(result[:invalid_namespace_ids]).to contain_exactly(non_existing_record_id)
        expect(result[:message]).to eq(
          "the following namespace ids were invalid and have been ignored: #{non_existing_record_id}"
        )
      end

      context 'with invalid namespace ids exceeding the limits' do
        let(:invalid_namespace_ids) { (0..5).map { |i| non_existing_record_id + i } }

        it 'returns concatenated warning message' do
          expect(result[:message]).to eq(
            "the following namespace ids were invalid and have been ignored: " \
              "#{invalid_namespace_ids.first(5).join(', ')} and 1 more"
          )
        end
      end
    end

    context 'with empty CSV' do
      let(:csv_content) { '' }

      it 'returns results containing empty namespace id arrays and message' do
        expect(result[:success]).to be(true)
        expect(result[:valid_namespace_ids]).to be_empty
        expect(result[:invalid_namespace_ids]).to be_empty
        expect(result[:message]).to be_nil
      end
    end

    context 'with invalid data in CSV' do
      let(:invalid_namespace_ids) { ['abc', 3.5, non_existing_record_id] }

      it 'filters out invalid entries and returns valid and invalid namespace ids' do
        expect(result[:success]).to be(true)
        expect(result[:valid_namespace_ids]).to match_array(valid_namespace_ids)
        expect(result[:invalid_namespace_ids]).to contain_exactly(non_existing_record_id)
      end
    end

    context 'with duplicate values' do
      let(:invalid_namespace_ids) { valid_namespace_ids + [non_existing_record_id] }

      it 'removes duplicates and returns unique valid and invalid namespace ids' do
        expect(result[:success]).to be(true)
        expect(result[:valid_namespace_ids]).to match_array(valid_namespace_ids)
        expect(result[:invalid_namespace_ids]).to contain_exactly(non_existing_record_id)
      end
    end

    context 'with a file that cannot be parsed' do
      let(:csv_content) { '"123' }

      it 'returns empty namespace id arrays and error message' do
        expect(result[:success]).to be(false)
        expect(result[:valid_namespace_ids]).to be_empty
        expect(result[:invalid_namespace_ids]).to be_empty
        expect(result[:message]).to eq(
          'Failed to assign namespaces due to error processing CSV: Unclosed quoted field in line 1.'
        )
      end
    end

    context 'with large number of namespace ids' do
      it 'batches the namespace id validation' do
        stub_const('Notifications::TargetedMessages::NamespaceIdsBuilder::NAMESPACE_IDS_BATCH', 1)

        expect(Namespace).to receive(:id_in).exactly(3).times.and_call_original

        result
      end

      it 'raises error when namespace ids limit is exceeded' do
        stub_const('Notifications::TargetedMessages::NamespaceIdsBuilder::MAX_NAMESPACE_IDS', 1)

        expect(result[:success]).to be(false)
        expect(result[:valid_namespace_ids]).to be_empty
        expect(result[:invalid_namespace_ids]).to be_empty
        expect(result[:message]).to eq(
          'Failed to assign namespaces due to error processing CSV: namespace ids exceed the maximum limit.'
        )
      end
    end
  end
end
