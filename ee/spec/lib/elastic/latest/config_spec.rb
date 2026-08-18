# frozen_string_literal: true

require 'spec_helper'
require_relative './config_shared_examples'

RSpec.describe Elastic::Latest::Config, feature_category: :global_search do
  describe '.settings' do
    it_behaves_like 'config settings return correct values'
  end

  describe '.mappings' do
    it 'returns config' do
      expect(described_class.mapping).to be_a(Elasticsearch::Model::Indexing::Mappings)
    end
  end

  describe '.index_name' do
    it 'uses the elasticsearch_prefix setting' do
      allow(Gitlab::CurrentSettings).to receive(:elasticsearch_prefix).and_return('custom-prefix')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))

      expect(described_class.index_name).to eq('custom-prefix-test')
    end

    it 'uses default prefix when setting returns default value' do
      allow(Gitlab::CurrentSettings).to receive(:elasticsearch_prefix).and_return('gitlab')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      expect(described_class.index_name).to eq('gitlab-development')
    end
  end
end
