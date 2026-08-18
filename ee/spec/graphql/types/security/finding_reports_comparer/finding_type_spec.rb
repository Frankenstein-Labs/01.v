# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComparedSecurityReportFinding'],
  feature_category: :vulnerability_management do
  let(:expected_fields) do
    %i[
      uuid title description state severity found_by_pipeline_iid
      location identifiers scanner details ai_resolution_enabled unverified
      matches_auto_dismiss_policy auto_severity_override
    ]
  end

  it { expect(described_class).to have_graphql_fields(expected_fields) }
end
