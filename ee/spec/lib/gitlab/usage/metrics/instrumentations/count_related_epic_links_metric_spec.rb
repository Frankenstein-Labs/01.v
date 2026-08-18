# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountRelatedEpicLinksMetric, feature_category: :service_ping do
  before_all do
    create(:related_epic_link)
    create(:related_epic_link)
  end

  let(:expected_value) { 2 }
  let(:expected_query) do
    <<~SQL.squish
      SELECT COUNT("related_epic_links"."id") FROM "related_epic_links"
    SQL
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
