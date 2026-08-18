# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctTopLevelGroupsWithMavenVirtualRegistriesMetric, feature_category: :service_ping do
  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }
  let_it_be(:group3) { create(:group) }

  let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry, group: group1) }
  let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry, group: group1) }
  let_it_be(:registry3) { create(:virtual_registries_packages_maven_registry, group: group2) }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 2 }

    let(:expected_query) do
      'SELECT COUNT(DISTINCT "virtual_registries_packages_maven_registries"."group_id") ' \
        'FROM "virtual_registries_packages_maven_registries"'
    end
  end
end
