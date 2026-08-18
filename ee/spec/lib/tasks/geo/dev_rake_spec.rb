# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'geo:dev:ssf_metrics', feature_category: :geo_replication do
  include RakeHelpers

  before_all do
    Rake.application.rake_require 'tasks/geo/dev'
    Rake.application.rake_require 'tasks/gitlab/geo/dev'
    Rake::Task.define_task(:environment)
  end

  let(:tempfile) { Tempfile.new('geo_node_usage.json') }

  subject(:task) { run_rake_task('geo:dev:ssf_metrics') }

  before do
    Rake::Task['gitlab:geo:dev:ssf_metrics'].reenable

    allow(Rails.root).to receive(:join)
      .with("ee/config/metrics/object_schemas/geo_node_usage.json")
      .and_return(tempfile.path)
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  def parsed_result
    ::Gitlab::Json.safe_parse(File.read(tempfile.path))
  end

  def properties
    parsed_result['items']['properties']
  end

  it 'generates a JSON file with resource status fields' do
    task

    expect(parsed_result).to include('type' => 'array')
    expect(parsed_result['items']).to include('type' => 'object')
    expect(properties).to be_a(Hash)

    GeoNodeStatus::RESOURCE_STATUS_FIELDS.each do |field|
      expect(properties).to have_key(field)
      expect(properties[field]).to include('type' => 'number')
      expect(properties[field]).to have_key('description')
    end
  end

  it 'uses prometheus metric descriptions when available' do
    prometheus_metrics = GeoNodeStatus.replicator_class_prometheus_metrics.with_indifferent_access

    task

    prometheus_metrics.each do |field, description|
      next unless properties&.key?(field)

      expect(properties[field]['description']).to eq(description)
    end
  end

  it 'falls back to humanized field name when no prometheus metric exists' do
    allow(GeoNodeStatus).to receive(:replicator_class_prometheus_metrics).and_return({})

    task

    GeoNodeStatus::RESOURCE_STATUS_FIELDS.each do |field|
      expect(properties[field]['description']).to eq(field.humanize)
    end
  end

  it 'writes sorted properties' do
    task

    expect(properties&.keys).to eq(properties&.keys&.sort)
  end
end
