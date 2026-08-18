# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountRelatedWorkItemLinksMetric, feature_category: :service_ping do
  before_all do
    namespace = create(:namespace)
    source_epic1 = create(:work_item, :epic, namespace: namespace)
    source_epic2 = create(:work_item, :epic, namespace: namespace)

    target_epic1 = create(:work_item, :epic, namespace: namespace)
    target_epic2 = create(:work_item, :epic, namespace: namespace)

    create(:work_item_link, source: source_epic1, target: target_epic1)
    create(:work_item_link, source: source_epic2, target: target_epic2)

    create(:work_item_link)
  end

  let(:expected_value) { 2 }
  let(:work_item_type) { build(:work_item_system_defined_type, :epic) }
  let(:expected_query) do
    <<~SQL.squish
      SELECT COUNT("issue_links"."id") FROM "issue_links"
      INNER JOIN "issues" "target" ON "target"."id" = "issue_links"."target_id"
      WHERE "target"."work_item_type_id" = #{work_item_type.id}
    SQL
  end

  it_behaves_like 'a correct instrumented metric value and query',
    { time_frame: 'all', data_source: 'database', options: { target_type: 'epic' } }
end
