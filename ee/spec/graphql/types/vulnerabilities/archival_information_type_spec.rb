# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['VulnerabilityArchivalInformation'], feature_category: :vulnerability_management do
  let(:expected_fields) { %i[about_to_be_archived expected_to_be_archived_on] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
end
