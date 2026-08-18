# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::PipelineSecurityReportFinding, feature_category: :vulnerability_management do
  it do
    expected_permissions = %i[admin_vulnerability create_issue]

    expect(described_class).to have_graphql_fields(expected_permissions).only
  end
end
