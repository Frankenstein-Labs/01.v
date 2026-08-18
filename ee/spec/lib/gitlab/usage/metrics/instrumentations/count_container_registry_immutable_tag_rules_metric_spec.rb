# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountContainerRegistryImmutableTagRulesMetric, feature_category: :service_ping do
  let_it_be(:project) { create(:project) }

  let(:expected_value) { 2 }
  let(:expected_query) do
    'SELECT COUNT("container_registry_protection_tag_rules"."id") ' \
      'FROM "container_registry_protection_tag_rules" ' \
      'WHERE "container_registry_protection_tag_rules"."minimum_access_level_for_push" IS NULL ' \
      'AND "container_registry_protection_tag_rules"."minimum_access_level_for_delete" IS NULL'
  end

  before_all do
    create(:container_registry_protection_tag_rule, :immutable, project: project, tag_name_pattern: 'prod')
    create(:container_registry_protection_tag_rule, :immutable, project: project, tag_name_pattern: 'stable')
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
