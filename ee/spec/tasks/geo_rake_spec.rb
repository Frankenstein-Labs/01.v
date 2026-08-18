# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'geo rake tasks', :geo, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    Rake.application.rake_require 'active_record/railties/databases'
    Rake.application.rake_require 'tasks/gitlab/db'
    Rake.application.rake_require 'tasks/gitlab/geo/dev'
    Rake.application.rake_require 'tasks/gitlab/geo/replication'
    Rake.application.rake_require 'tasks/gitlab/geo'
    Rake.application.rake_require 'tasks/geo/dev'
    Rake.application.rake_require 'tasks/geo/replication'
    Rake.application.rake_require 'tasks/geo'
    Rake.application.rake_require 'tasks/gitlab/helpers'

    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_licensed_features(geo: true)
  end

  describe 'geo:set_primary_node (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:set_primary_node']).to receive(:invoke)
      run_rake_task('geo:set_primary_node')
    end
  end

  describe 'geo:set_secondary_as_primary (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:set_secondary_as_primary']).to receive(:invoke)
      run_rake_task('geo:set_secondary_as_primary')
    end
  end

  describe 'geo:update_primary_node_url (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:update_primary_node_url']).to receive(:invoke)
      run_rake_task('geo:update_primary_node_url')
    end
  end

  describe 'geo:status (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:status']).to receive(:invoke)
      run_rake_task('geo:status')
    end
  end

  describe 'geo:site:role (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:site:role']).to receive(:invoke)
      run_rake_task('geo:site:role')
    end
  end

  describe 'geo:replication:pause (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:replication:pause']).to receive(:invoke)
      run_rake_task('geo:replication:pause')
    end
  end

  describe 'geo:replication:resume (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:replication:resume']).to receive(:invoke)
      run_rake_task('geo:replication:resume')
    end
  end

  describe 'geo:dev:ssf_metrics (alias)' do
    it 'invokes the underlying task' do
      expect(Rake::Task['gitlab:geo:dev:ssf_metrics']).to receive(:invoke)
      run_rake_task('geo:dev:ssf_metrics')
    end
  end
end
