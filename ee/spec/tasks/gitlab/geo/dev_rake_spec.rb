# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:geo:dev rake tasks', :geo, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    Rake.application.rake_require 'tasks/gitlab/helpers'
    Rake.application.rake_require 'tasks/gitlab/geo/dev'
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_licensed_features(geo: true)
  end

  describe 'gitlab:geo:dev:ssf_metrics' do
    let(:config_path) { Rails.root.join("ee/config/metrics/object_schemas/geo_node_usage.json") }

    it 'writes the SSF prometheus metrics in the correct config file path' do
      file = instance_double(File)
      expect(::File).to receive(:open).with(config_path, 'w').and_yield(file)
      expect(file).to receive(:puts).with(an_instance_of(::String))

      run_rake_task('gitlab:geo:dev:ssf_metrics')
    end
  end
end
