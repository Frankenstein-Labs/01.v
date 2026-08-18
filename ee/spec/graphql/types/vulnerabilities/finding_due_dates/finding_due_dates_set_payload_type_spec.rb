# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['FindingDueDatesSetPayload'], feature_category: :vulnerability_management do
  let(:expected_fields) do
    %i[
      assigned
      removed
      skipped
      errors
    ]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
