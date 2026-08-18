# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountEpicsWithParentsMetric, feature_category: :service_ping do
  before_all do
    group = create(:group)

    parent_epic = create(:epic, group: group)
    create(:epic, group: group, parent: parent_epic)
    create(:epic, group: group, parent: parent_epic)
  end

  let(:expected_value) { 2 }
  let(:expected_query) do
    <<~SQL.squish
      SELECT COUNT("epics"."id") FROM "epics"
      WHERE "epics"."parent_id" IS NOT NULL
    SQL
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
