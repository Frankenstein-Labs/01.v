# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountParentLinksMetric, feature_category: :service_ping do
  before_all do
    namespace = create(:group)

    parent_epic = create(:work_item, :epic, namespace: namespace)
    child_epic = create(:work_item, :epic, namespace: namespace)
    child_issue = create(:work_item, :issue, namespace: namespace)

    create(:parent_link, work_item_parent: parent_epic, work_item: child_epic)
    create(:parent_link, work_item_parent: parent_epic, work_item: child_issue)

    create(:parent_link,
      work_item_parent: create(:work_item, :issue, namespace: namespace),
      work_item: create(:work_item, :task, namespace: namespace))
  end

  context 'when parent_type is epic' do
    let(:expected_value) { 2 }
    let(:work_item_type) { build(:work_item_system_defined_type, :epic) }
    let(:expected_query) do
      <<~SQL.squish
        SELECT COUNT("work_item_parent_links"."id") FROM "work_item_parent_links"
        INNER JOIN "issues" "work_item_parent" ON "work_item_parent"."id" = "work_item_parent_links"."work_item_parent_id"
        WHERE "work_item_parent"."work_item_type_id" = #{work_item_type.id}
      SQL
    end

    it_behaves_like 'a correct instrumented metric value and query',
      { time_frame: 'all', data_source: 'database', options: { parent_type: 'epic' } }
  end

  context 'when parent_type is issue' do
    let(:expected_value) { 1 }
    let(:work_item_type) { build(:work_item_system_defined_type, :issue) }
    let(:expected_query) do
      <<~SQL.squish
        SELECT COUNT("work_item_parent_links"."id") FROM "work_item_parent_links"
        INNER JOIN "issues" "work_item_parent" ON "work_item_parent"."id" = "work_item_parent_links"."work_item_parent_id"
        WHERE "work_item_parent"."work_item_type_id" = #{work_item_type.id}
      SQL
    end

    it_behaves_like 'a correct instrumented metric value and query',
      { time_frame: 'all', data_source: 'database', options: { parent_type: 'issue' } }
  end

  it 'raises an exception if parent_type option is not present' do
    expect do
      described_class.new(time_frame: 'all')
    end.to raise_error(ArgumentError, /valid parent_type options attribute is required/)
  end

  it 'raises an exception if parent_type option is not valid' do
    expect do
      described_class.new(time_frame: 'all', options: { parent_type: 'invalid' })
    end.to raise_error(ArgumentError, /valid parent_type options attribute is required/)
  end
end
