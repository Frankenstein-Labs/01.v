# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VulnerabilityRepresentationInformation'], feature_category: :vulnerability_management do
  let(:expected_fields) { %i[resolved_in_commit_sha] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
