# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::TooManyReplicasEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::TooManyReplicasEvent.new(data: {}) }

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    it 'is a no-op' do
      expect(described_class.new.handle_event(event)).to be_nil
    end
  end
end
