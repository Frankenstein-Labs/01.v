# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../lib/generators/geo/replicator/status_schema'

RSpec.describe Geo::Replicator::StatusSchema, feature_category: :geo_replication do
  subject(:schema) do
    described_class.new(file_name: 'cool_widget', replicable_title_plural: 'Cool Widgets', milestone: '19.1')
  end

  it 'builds status fields using the pluralized prefix', :aggregate_failures do
    expect(schema.status_field_prefix).to eq('cool_widgets')
    expect(schema.status_fields).to include(
      'cool_widgets_count', 'cool_widgets_verified_count', 'cool_widgets_oldest_unsynced_time'
    )
  end

  it 'builds the API-doc JSON field defaults', :aggregate_failures do
    out = schema.api_doc_json_fields('  ')

    expect(out).to include('"cool_widgets_count": 0')
    expect(out).to include('"cool_widgets_synced_in_percentage": "0.00%"')
    expect(out).to include('"cool_widgets_registry_count": null')
  end

  it 'builds Prometheus rows with the milestone and human-readable title', :aggregate_failures do
    rows = schema.prometheus_metrics_rows

    expect(rows).to include('`geo_cool_widgets`')
    expect(rows).to include('19.1')
    expect(rows).to include('Number of cool widgets on primary')
  end
end
