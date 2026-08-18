# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithComplianceFrameworkRequirementsAndControlsMetric, feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) { create(:compliance_requirement, framework: framework, name: 'Project Control Requirement') }

  before_all do
    create(:compliance_requirements_control, compliance_requirement: requirement)
    create(:compliance_framework_project_setting,
      project: project,
      compliance_management_framework: framework
    )
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' } do
    let(:expected_value) { 1 }
    let(:expected_query) do
      <<~SQL.squish
        SELECT COUNT(DISTINCT "projects"."id")#{' '}
        FROM "projects"
        INNER JOIN "project_compliance_framework_settings"#{' '}
          ON "project_compliance_framework_settings"."project_id" = "projects"."id"
        INNER JOIN "compliance_management_frameworks"#{' '}
          ON "compliance_management_frameworks"."id" = "project_compliance_framework_settings"."framework_id"
        INNER JOIN "compliance_requirements"#{' '}
          ON "compliance_requirements"."framework_id" = "compliance_management_frameworks"."id"
        INNER JOIN "compliance_requirements_controls"#{' '}
          ON "compliance_requirements_controls"."compliance_requirement_id" = "compliance_requirements"."id"
      SQL
    end
  end

  context 'when project has no framework' do
    let_it_be(:project_without_framework) { create(:project, namespace: create(:group)) }

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:expected_value) { 1 }
    end
  end

  context 'when framework has no controls' do
    let_it_be(:namespace2) { create(:group) }
    let_it_be(:project2) { create(:project, namespace: namespace2) }
    let_it_be(:framework2) { create(:compliance_framework, namespace: namespace2) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: framework2, name: 'No Controls Requirement') }

    before_all do
      create(:compliance_framework_project_setting,
        project: project2,
        compliance_management_framework: framework2
      )
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all' } do
      let(:expected_value) { 1 }
    end
  end
end
