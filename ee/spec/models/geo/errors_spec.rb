# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Errors, :geo, type: :model, feature_category: :geo_replication do
  RSpec.shared_examples 'logs warning on initialization' do
    it 'logs a warning when initialized' do
      expect(Gitlab::Geo::Logger).to receive(:warn).with(hash_including(expected_log_data))

      error
    end
  end

  describe 'StatusTimeoutError' do
    subject(:error) { described_class::StatusTimeoutError.new }

    it 'returns the correct error message' do
      expect(error.message).to eq('Generating Geo node status is taking too long')
    end
  end

  describe 'ReplicableExcludedFromVerificationError' do
    subject(:error) do
      described_class::ReplicableExcludedFromVerificationError.new(
        model_class: 'Upload',
        model_record_id: 123
      )
    end

    let(:expected_log_data) do
      {
        message: 'File is not checksummable because the replicable is excluded from verification',
        model_class: 'Upload',
        model_record_id: 123
      }
    end

    it_behaves_like 'logs warning on initialization'

    it 'returns the correct error message' do
      expect(error.message).to eq('File is not checksummable - Upload 123 is excluded from verification')
    end

    it 'stores the model class' do
      expect(error.model_class).to eq('Upload')
    end

    it 'stores the model record id' do
      expect(error.model_record_id).to eq(123)
    end
  end

  describe 'ReplicableDoesNotExistError' do
    subject(:error) do
      described_class::ReplicableDoesNotExistError.new(
        file_path: '/path/to/missing/file.txt'
      )
    end

    let(:expected_log_data) do
      {
        message: 'File is not checksummable because it does not exist',
        file_path: '/path/to/missing/file.txt'
      }
    end

    it_behaves_like 'logs warning on initialization'

    it 'returns the correct error message' do
      expect(error.message).to eq("File is not checksummable - file does not exist at: /path/to/missing/file.txt")
    end

    it 'stores the file path' do
      expect(error.file_path).to eq('/path/to/missing/file.txt')
    end
  end
end
