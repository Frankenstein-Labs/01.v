# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingEnrichments::PurgeWorker, feature_category: :vulnerability_management do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(::Security::FindingEnrichments::PurgeService).to receive(:purge_stale_records)
    end

    it 'delegates the call to PurgeService' do
      perform

      expect(::Security::FindingEnrichments::PurgeService).to have_received(:purge_stale_records)
    end
  end
end
