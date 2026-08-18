# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::KnowledgeGraph::Logger, feature_category: :knowledge_graph do
  subject(:logger) { described_class.new('/dev/null') }

  it_behaves_like 'a json logger', {}

  describe '.file_name_noext' do
    it 'returns the log file name without extension' do
      expect(described_class.file_name_noext).to eq('knowledge_graph')
    end
  end

  describe '#default_attributes' do
    it 'includes feature_category' do
      output = StringIO.new
      logger = described_class.new(output)

      logger.info(message: 'test')

      log_entry = Gitlab::Json.safe_parse(output.string)
      expect(log_entry['feature_category']).to eq('knowledge_graph')
    end
  end
end
