# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountEventStreamingDestinationsMetric,
  feature_category: :compliance_management do
  let_it_be(:destination) { create(:external_audit_event_destination) }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 1 }
    let(:expected_query) { 'SELECT COUNT("audit_events_external_audit_event_destinations"."id") FROM "audit_events_external_audit_event_destinations"' }
  end

  it_behaves_like 'a correct instrumented metric value and query', { options: { with_assigned_compliance_frameworks: true }, time_frame: 'all', data_source: 'database' } do
    let_it_be(:project) { create :project, group: destination.group }
    let_it_be(:assgned_framework) { create :compliance_framework_project_setting, project: project }
    let_it_be(:uncounted_destination) { create(:external_audit_event_destination) }
    let_it_be(:project_without_framework) { create :project, group: uncounted_destination.group }
    let(:expected_value) { 1 }
    let(:expected_query) do
      query = <<~SQL
      SELECT COUNT("audit_events_external_audit_event_destinations"."id") FROM "audit_events_external_audit_event_destinations" WHERE (EXISTS (SELECT 1 FROM "namespaces" JOIN projects ON projects.namespace_id = namespaces.id JOIN project_compliance_framework_settings ON project_compliance_framework_settings.project_id = projects.id WHERE "namespaces"."type" = 'Group' AND "project_compliance_framework_settings"."framework_id" IS NOT NULL AND "namespaces"."id" = "audit_events_external_audit_event_destinations"."namespace_id"))
      SQL
      # equality matcher in shared example needs this
      query.strip
    end
  end
end
