# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../app/models/geo/errors/message_with_file_path'

RSpec.describe Geo::Errors::MessageWithFilePath, :geo, feature_category: :geo_replication do
  describe '.build' do
    it 'builds a message with prefix and file path' do
      prefix = 'File is not checksummable - file does not exist at: '
      file_path = '/var/opt/gitlab/uploads/file.txt'

      result = described_class.build(prefix: prefix, file_path: file_path)

      expect(result).to eq("#{prefix}#{file_path}")
    end

    it 'truncates long paths to fit within MAX_MESSAGE_LENGTH' do
      prefix = 'Error: '
      long_path = 'a' * 300

      result = described_class.build(prefix: prefix, file_path: long_path)

      expect(result.length).to be <= described_class::MAX_MESSAGE_LENGTH
      expect(result).to start_with(prefix)
    end

    it 'handles nil file path' do
      prefix = 'File error: '

      result = described_class.build(prefix: prefix, file_path: nil)

      expect(result).to eq("#{prefix}(path unavailable)")
    end

    it 'preserves file name when truncating long paths' do
      prefix = 'Error: '
      file_path = "/very/long/path/#{'nested/directory/' * 20}some_file_with_a_long_name.txt"

      result = described_class.build(prefix: prefix, file_path: file_path)

      expect(result).to end_with('some_file_with_a_long_name.txt')
      expect(result).to include('some_file_with_a_long_name.txt')
      expect(result.length).to be <= described_class::MAX_MESSAGE_LENGTH
    end

    it 'returns exact max message length when path is exactly at the limit' do
      prefix = 'Error message prefix: '
      max_path_length = described_class::MAX_MESSAGE_LENGTH - prefix.length
      exact_path = 'a' * max_path_length

      result = described_class.build(prefix: prefix, file_path: exact_path)

      expect(result).to eq("#{prefix}#{exact_path}")
      expect(result.length).to eq(described_class::MAX_MESSAGE_LENGTH)
    end

    it 'truncates path by one character when over the limit' do
      prefix = 'Error message prefix: '
      max_path_length = described_class::MAX_MESSAGE_LENGTH - prefix.length
      over_limit_path = 'a' * (max_path_length + 1)

      result = described_class.build(prefix: prefix, file_path: over_limit_path)

      expect(result.length).to eq(described_class::MAX_MESSAGE_LENGTH)
      expect(result).to start_with(prefix)
    end
  end

  describe '.truncated_path' do
    it 'returns the path unchanged if it fits within max_length' do
      path = '/var/opt/gitlab/uploads/file.txt'
      max_length = 100

      result = described_class.truncated_path(path, max_length)

      expect(result).to eq(path)
    end

    it 'truncates path to max_length when path is too long' do
      path = '/very/long/path/that/exceeds/max/length'
      max_length = 10

      result = described_class.truncated_path(path, max_length)

      expect(result.length).to eq(max_length)
      expect(result).to eq(path[-max_length..])
    end

    it 'returns (path unavailable) when path is nil' do
      result = described_class.truncated_path(nil, 100)

      expect(result).to eq('(path unavailable)')
    end

    it 'handles empty path' do
      result = described_class.truncated_path('', 100)

      expect(result).to eq('')
    end

    it 'handles path exactly at max_length' do
      path = 'a' * 50
      max_length = 50

      result = described_class.truncated_path(path, max_length)

      expect(result).to eq(path)
    end
  end
end
