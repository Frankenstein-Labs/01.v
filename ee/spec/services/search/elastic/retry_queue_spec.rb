# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::RetryQueue, :clean_gitlab_redis_shared_state, feature_category: :global_search do
  let(:ref_class) { ::Search::Elastic::DocumentReference }
  let(:fake_refs) { (1..10).map { |i| ref_class.new(Issue, i, "issue_#{i}", 'project_1') } }

  describe 'inheritance' do
    it 'inherits from ProcessBookkeepingService' do
      expect(described_class).to be < ::Elastic::ProcessBookkeepingService
    end
  end

  describe '.redis_set_key' do
    it 'returns correct redis key for retry queue' do
      expect(described_class.redis_set_key(0)).to eq('elastic:retry_queue:0:zset')
    end
  end

  describe '.redis_score_key' do
    it 'returns correct redis score key for retry queue' do
      expect(described_class.redis_score_key(0)).to eq('elastic:retry_queue:0:score')
    end
  end
end
