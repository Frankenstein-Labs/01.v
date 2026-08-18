# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReviewerAssignment::PendingInitialAssignment,
  :clean_gitlab_redis_shared_state,
  feature_category: :code_review_workflow do
  let_it_be(:merge_request) { create(:merge_request) }

  describe '.mark / .consume' do
    it 'returns true on first consume and false thereafter' do
      described_class.mark(merge_request)

      expect(described_class.consume(merge_request)).to be(true)
      expect(described_class.consume(merge_request)).to be(false)
    end

    it 'returns false when nothing has been marked' do
      expect(described_class.consume(merge_request)).to be(false)
    end

    it 'expires the flag after the configured TTL' do
      described_class.mark(merge_request)

      Gitlab::Redis::SharedState.with do |redis|
        ttl = redis.ttl(described_class.key(merge_request.id))
        expect(ttl).to be > 0
        expect(ttl).to be <= described_class::TTL.to_i
      end
    end

    it 'scopes the key per merge request' do
      other_mr = create(:merge_request)
      described_class.mark(merge_request)

      expect(described_class.consume(other_mr)).to be(false)
      expect(described_class.consume(merge_request)).to be(true)
    end
  end
end
