# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['FindingDueDatesSetInput'], feature_category: :vulnerability_management do
  let(:expected_arguments) do
    %i[
      finding_uuid
      due_date
    ]
  end

  subject { described_class }

  it { is_expected.to have_graphql_arguments(expected_arguments) }
end
