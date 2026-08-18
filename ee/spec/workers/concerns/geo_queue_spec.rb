# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoQueue, feature_category: :geo_replication do
  let(:worker) do
    Class.new do
      def self.name
        'Gitlab::Geo::TestWorker'
      end

      include ApplicationWorker
      include GeoQueue
    end
  end

  it 'sets the queue namespace to geo' do
    expect(worker.sidekiq_options['queue_namespace']).to eq(:geo)
  end

  it 'sets the feature category to geo_replication' do
    expect(worker.get_feature_category).to eq(:geo_replication)
  end
end
