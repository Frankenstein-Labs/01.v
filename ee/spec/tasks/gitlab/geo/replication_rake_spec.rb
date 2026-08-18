# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:geo:replication rake tasks', :geo, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    Rake.application.rake_require 'tasks/gitlab/helpers'
    Rake.application.rake_require 'tasks/gitlab/geo/replication'

    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_licensed_features(geo: true)
  end

  describe 'gitlab:geo:replication:pause' do
    it 'invokes ReplicationToggleRequestService with enabled: false' do
      service = instance_double(Geo::ReplicationToggleRequestService)
      expect(Geo::ReplicationToggleRequestService).to receive(:new).with(enabled: false).and_return(service)
      expect(service).to receive(:execute)
      run_rake_task('gitlab:geo:replication:pause')
    end
  end

  describe 'gitlab:geo:replication:resume' do
    it 'invokes ReplicationToggleRequestService with enabled: true' do
      service = instance_double(Geo::ReplicationToggleRequestService)
      expect(Geo::ReplicationToggleRequestService).to receive(:new).with(enabled: true).and_return(service)
      expect(service).to receive(:execute)
      run_rake_task('gitlab:geo:replication:resume')
    end
  end
end
