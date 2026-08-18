# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260810120000_backfill_groups_to_elasticsearch.rb')

RSpec.describe BackfillGroupsToElasticsearch, :elastic, feature_category: :global_search do
  let(:version) { 20260810120000 }

  include_examples 'migration reindexes all data' do
    # Include both top-level groups and subgroups to verify parent preloading works correctly
    let(:objects) do
      parent_group = create(:group)
      [
        parent_group,
        create(:group),
        create(:group, parent: parent_group)
      ]
    end

    let(:factory_to_create_objects) { :group }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 50_000 }
  end

  describe 'N+1 queries with subgroups', :use_sql_query_cache do
    let(:migration) { described_class.new(version) }

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    it 'does not trigger N+1 queries when processing subgroups' do
      parent = create(:group)
      create(:group, parent: parent)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { migration.migrate }

      parent2 = create(:group)
      create_list(:group, 2, parent: parent2)
      migration.set_migration_state(current_id: 0)

      expect { migration.migrate }.to issue_same_number_of_queries_as(control)
    end
  end
end
