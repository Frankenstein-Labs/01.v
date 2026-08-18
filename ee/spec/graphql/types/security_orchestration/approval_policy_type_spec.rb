# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ApprovalPolicy'], feature_category: :security_policy_management do
  let(:fields) do
    %i[id policy_configuration_id name description edit_path enabled policy_scope updated_at yaml csp]
  end

  include_context 'with approval policy specific fields'

  it { expect(described_class).to have_graphql_fields(fields + type_specific_fields) }
end
