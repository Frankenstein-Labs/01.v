# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::NotifySeatsExceededBatchWorker, feature_category: :subscription_management do
  describe '#perform' do
    it 'calls NotifySeatsExceededBatchService' do
      expect(GitlabSubscriptions::NotifySeatsExceededBatchService).to receive(:execute)

      described_class.new.perform
    end
  end
end
