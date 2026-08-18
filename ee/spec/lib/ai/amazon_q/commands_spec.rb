# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::Commands, feature_category: :duo_chat do
  describe 'MERGE_REQUEST_SUBCOMMANDS' do
    it 'does not include deprecated test command' do
      expect(described_class::MERGE_REQUEST_SUBCOMMANDS).not_to include('test')
    end

    it 'includes supported commands' do
      expect(described_class::MERGE_REQUEST_SUBCOMMANDS).to contain_exactly('dev', 'review')
    end
  end

  describe 'ISSUE_SUBCOMMANDS' do
    it 'includes supported commands for issues' do
      expect(described_class::ISSUE_SUBCOMMANDS).to contain_exactly('dev', 'transform')
    end

    it 'does not include test command (never supported on issues)' do
      expect(described_class::ISSUE_SUBCOMMANDS).not_to include('test')
    end
  end

  describe 'DEPRECATED_COMMANDS' do
    it 'maps test to dev' do
      expect(described_class::DEPRECATED_COMMANDS['test']).to eq('dev')
    end

    it 'is frozen' do
      expect(described_class::DEPRECATED_COMMANDS).to be_frozen
    end
  end
end
