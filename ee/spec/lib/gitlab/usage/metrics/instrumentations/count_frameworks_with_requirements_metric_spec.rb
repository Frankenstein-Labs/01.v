# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountFrameworksWithRequirementsMetric, feature_category: :compliance_management do
  let_it_be(:namespace1) { create(:group) }
  let_it_be(:namespace2) { create(:group) }
  let_it_be(:namespace3) { create(:group) }

  let_it_be(:framework_with_requirements1) { create(:compliance_framework, namespace: namespace1) }
  let_it_be(:framework_with_requirements2) { create(:compliance_framework, namespace: namespace2) }
  let_it_be(:framework_without_requirements) { create(:compliance_framework, namespace: namespace3) }

  let_it_be(:requirement1) do
    create(:compliance_requirement, framework: framework_with_requirements1, name: 'Framework 1 Test Requirement')
  end

  let_it_be(:requirement2) do
    create(:compliance_requirement, framework: framework_with_requirements2, name: 'Framework 2 Test Requirement')
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' } do
    let(:expected_value) { 2 }
    let(:expected_query) do
      <<~SQL.squish
        SELECT COUNT(DISTINCT "compliance_management_frameworks"."id")#{' '}
        FROM "compliance_management_frameworks"
        INNER JOIN "compliance_requirements"#{' '}
          ON "compliance_requirements"."framework_id" = "compliance_management_frameworks"."id"
      SQL
    end
  end

  context 'with multiple requirements for the same framework' do
    let_it_be(:additional_requirement) do
      create(:compliance_requirement, framework: framework_with_requirements1, name: 'Another Requirement')
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' } do
      let(:expected_value) { 2 } # Still 2 frameworks with requirements, not counting duplicates
      let(:expected_query) do
        <<~SQL.squish
          SELECT COUNT(DISTINCT "compliance_management_frameworks"."id")#{' '}
          FROM "compliance_management_frameworks"
          INNER JOIN "compliance_requirements"#{' '}
            ON "compliance_requirements"."framework_id" = "compliance_management_frameworks"."id"
        SQL
      end
    end
  end
end
