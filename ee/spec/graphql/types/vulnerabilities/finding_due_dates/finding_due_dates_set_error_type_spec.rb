# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['FindingDueDatesSetError'], feature_category: :vulnerability_management do
  let(:expected_arguments) do
    %i[
      finding_uuid
      code
      message
    ]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_arguments) }
end
