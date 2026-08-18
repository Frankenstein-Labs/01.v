# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Preloaders::Base, feature_category: :global_search do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability1) { create(:vulnerability, :with_read, project: project) }
  let_it_be(:vulnerability2) { create(:vulnerability, :with_read, project: project) }
  let_it_be(:vulnerability3) { create(:vulnerability, :with_read, project: project) }

  let(:vulnerability_records) { [vulnerability1.vulnerability_read, vulnerability2.vulnerability_read] }
  let(:preloader) { described_class.new(vulnerability_records) }

  # Test helper for creating concrete implementation
  let(:concrete_preloader) do
    Class.new(described_class) do
      def perform_preload
        safe_preload do
          records.each_with_object({}) do |record, result|
            result[record_key(record)] = {
              project_name: record.project.name,
              severity: record.severity,
              state: record.state
            }
          end
        end
      end
    end.new(vulnerability_records)
  end

  describe '#initialize' do
    it 'normalizes input to array using Array()' do
      # Single record
      single_preloader = described_class.new(vulnerability1.vulnerability_read)
      expect(single_preloader.send(:records)).to eq([vulnerability1.vulnerability_read])

      # Nil input
      nil_preloader = described_class.new(nil)
      expect(nil_preloader.send(:records)).to eq([])

      # Array input (including empty)
      expect(preloader.send(:records)).to eq(vulnerability_records)
      expect(described_class.new([]).send(:records)).to eq([])
    end
  end

  describe '#preload' do
    it 'memoizes perform_preload result' do
      expected_data = { vulnerability1.id => "data1", vulnerability2.id => "data2" }
      allow(preloader).to receive(:perform_preload).and_return(expected_data)

      result1 = preloader.preload
      result2 = preloader.preload

      expect(preloader).to have_received(:perform_preload).once
      expect(result1).to eq(expected_data)
      expect(result2).to eq(expected_data)
    end
  end

  describe '#perform_preload' do
    it 'raises NotImplementedError for base class' do
      expect { preloader.send(:perform_preload) }.to raise_error(
        NotImplementedError,
        "#{described_class} must implement #perform_preload"
      )
    end
  end

  describe '#data_for' do
    context 'with concrete implementation' do
      it 'auto-preloads and returns data for specific records' do
        expect(concrete_preloader.preloaded?).to be false

        result = concrete_preloader.data_for(vulnerability1.vulnerability_read)

        expect(concrete_preloader.preloaded?).to be true
        expect(result).to include(
          project_name: project.name,
          severity: vulnerability1.severity,
          state: vulnerability1.state
        )
      end

      it 'returns nil for records without preloaded data' do
        concrete_preloader.preload
        expect(concrete_preloader.data_for(vulnerability3.vulnerability_read)).to be_nil
      end
    end
  end

  describe '#preloaded?' do
    it 'tracks preload state correctly' do
      expect(preloader.preloaded?).to be false

      allow(preloader).to receive(:perform_preload).and_return({})
      preloader.preload

      expect(preloader.preloaded?).to be true
    end
  end

  describe '#preloaded_data' do
    it 'returns empty hash when nil, actual data when preloaded' do
      expect(preloader.send(:preloaded_data)).to eq({})

      expected_data = { "key" => "value" }
      allow(preloader).to receive(:perform_preload).and_return(expected_data)
      preloader.preload

      expect(preloader.send(:preloaded_data)).to eq(expected_data)
    end
  end

  describe '#record_key' do
    it 'returns primary key value for records' do
      vulnerability_record = vulnerability1.vulnerability_read
      expected_value = vulnerability_record[vulnerability_record.class.primary_key]

      expect(preloader.send(:record_key, vulnerability_record)).to eq(expected_value)
      expect(preloader.send(:record_key, vulnerability_record)).to be_a(Integer)
    end
  end

  describe '#record_identifiers' do
    it 'returns unique, memoized record keys' do
      expected_ids = vulnerability_records.map { |r| r[r.class.primary_key] }

      # Test uniqueness and memoization
      result1 = preloader.send(:record_identifiers)
      result2 = preloader.send(:record_identifiers)

      expect(result1).to match_array(expected_ids)
      expect(result1.object_id).to eq(result2.object_id)
    end

    it 'removes duplicates and handles empty arrays' do
      duplicate_records = [vulnerability1.vulnerability_read, vulnerability1.vulnerability_read]
      duplicate_preloader = described_class.new(duplicate_records)
      expected_id = vulnerability1.vulnerability_read[vulnerability1.vulnerability_read.class.primary_key]

      expect(duplicate_preloader.send(:record_identifiers)).to eq([expected_id])
      expect(described_class.new([]).send(:record_identifiers)).to eq([])
    end
  end

  describe '#safe_preload' do
    it 'returns block result on success, empty hash on StandardError' do
      # Success case
      result = preloader.send(:safe_preload) { { success: true } }
      expect(result).to eq({ success: true })

      # Error case
      allow(::Gitlab::ErrorTracking).to receive(:track_exception)
      result = preloader.send(:safe_preload) { raise StandardError, 'test error' }
      expect(result).to eq({})
    end

    it 'tracks StandardError but lets other exceptions propagate' do
      error = StandardError.new('test error')
      expect(::Gitlab::ErrorTracking).to receive(:track_exception)
        .with(error, class: described_class.name)

      preloader.send(:safe_preload) { raise error }

      # Non-StandardError should propagate
      expect do
        preloader.send(:safe_preload) { raise NoMemoryError, 'system error' }
      end.to raise_error(NoMemoryError)
    end
  end

  describe 'integration scenarios' do
    it 'handles complete preload workflow successfully' do
      concrete_preloader.preload

      expect(concrete_preloader.preloaded?).to be true
      expect(concrete_preloader.data_for(vulnerability1.vulnerability_read)).to be_present
      expect(concrete_preloader.data_for(vulnerability2.vulnerability_read)).to be_present
    end

    it 'gracefully handles preload errors' do
      error_preloader = Class.new(described_class) do
        def perform_preload
          safe_preload { raise StandardError, 'preload failed' }
        end
      end.new(vulnerability_records)

      allow(::Gitlab::ErrorTracking).to receive(:track_exception)

      error_preloader.preload
      expect(error_preloader.preloaded?).to be true
      expect(error_preloader.data_for(vulnerability1.vulnerability_read)).to be_nil
    end

    it 'works with empty record sets' do
      empty_preloader = Class.new(described_class) do
        def perform_preload
          safe_preload { {} }
        end
      end.new([])

      empty_preloader.preload
      expect(empty_preloader.preloaded?).to be true
      expect(empty_preloader.send(:preloaded_data)).to eq({})
    end
  end
end
