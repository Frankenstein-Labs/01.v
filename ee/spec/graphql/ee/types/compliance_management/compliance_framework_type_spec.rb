# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFramework'], feature_category: :compliance_management do
  subject { described_class }

  fields = %w[
    id
    name
    description
    updated_at
    color
    default
    namespace_id
    pipeline_configuration_full_path
    projects
    approval_policies
    scan_result_policies
    scan_execution_policies
    pipeline_execution_policies
    pipeline_execution_schedule_policies
    compliance_requirements
    security_policies
    vulnerability_management_policies
    edit_path
  ]

  it 'has the correct fields' do
    is_expected.to have_graphql_fields(fields)
  end
end
