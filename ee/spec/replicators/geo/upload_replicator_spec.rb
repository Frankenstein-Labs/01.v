# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UploadReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:upload, :with_file) }

  include_examples 'a blob replicator'
  include_examples 'a blob replicator with upload replicator behavior'

  describe '#event_params' do
    it 'includes model_type so LogCursor can prune partitioned table lookups' do
      replicator = described_class.new(model_record: model_record)

      expect(replicator.event_params).to include('model_type' => model_record.model_type)
    end
  end
end
