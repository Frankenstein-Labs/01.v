# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctTopLevelGroupsWithContainerRegistryImmutableTagRulesMetric, feature_category: :service_ping do
  let_it_be(:top_level_group1) { create(:group) }
  let_it_be(:top_level_group2) { create(:group) }
  let_it_be(:subgroup1) { create(:group, parent: top_level_group1) }
  let_it_be(:project1) { create(:project, namespace: top_level_group1) }
  let_it_be(:project2) { create(:project, namespace: subgroup1) }
  let_it_be(:project3) { create(:project, namespace: top_level_group2) }

  let(:expected_value) { 2 }
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "root_namespaces"."id") ' \
      'FROM "container_registry_protection_tag_rules" ' \
      'INNER JOIN "projects" ON "projects"."id" = "container_registry_protection_tag_rules"."project_id" ' \
      'INNER JOIN "namespaces" ON "namespaces"."id" = "projects"."namespace_id" ' \
      'INNER JOIN namespaces AS root_namespaces ON root_namespaces.id = namespaces.traversal_ids[1] ' \
      'WHERE "container_registry_protection_tag_rules"."minimum_access_level_for_push" IS NULL ' \
      'AND "container_registry_protection_tag_rules"."minimum_access_level_for_delete" IS NULL ' \
      "AND (root_namespaces.type = 'Group' AND root_namespaces.parent_id IS NULL)"
  end

  before_all do
    create(:container_registry_protection_tag_rule, :immutable, project: project1)
    create(:container_registry_protection_tag_rule, :immutable, project: project2) # Same top-level group as project1
    create(:container_registry_protection_tag_rule, :immutable, project: project3)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
