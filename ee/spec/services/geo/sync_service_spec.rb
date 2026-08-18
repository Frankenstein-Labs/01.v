# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SyncService, feature_category: :geo_replication do
  let_it_be(:model_record, freeze: true) { create(:project) }
  let(:replicator) { model_record.replicator }

  subject(:sync_service) { described_class.new('project_repository', model_record.id) }

  describe '#execute' do
    it 'executes the consume part of the replication' do
      expect(::Gitlab::Geo::Replicator).to receive(:for_replicable_params)
        .with(replicator.replicable_params)
        .and_return(replicator)
      expect(replicator).to receive(:sync)

      sync_service.execute
    end
  end
end
