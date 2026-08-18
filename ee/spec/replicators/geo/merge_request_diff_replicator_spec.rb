# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::MergeRequestDiffReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:merge_request_diff, :external) }

  include_examples 'a blob replicator'

  describe '#calculate_checksum' do
    subject(:replicator) { described_class.new(model_record_id: model_record.id) }

    context 'when merge request diff is not stored externally' do
      let(:model_record) { create(:merge_request_diff) } # Without :external trait

      it 'raises an error indicating it is excluded from verification' do
        expect { replicator.calculate_checksum }.to raise_error(
          Geo::Errors::ReplicableExcludedFromVerificationError,
          "File is not checksummable - MergeRequestDiff #{model_record.id} is excluded from verification"
        )
      end
    end
  end
end
