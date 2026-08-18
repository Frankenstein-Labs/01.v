# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['IssueSort'], feature_category: :team_planning do
  it { expect(described_class.graphql_name).to eq('IssueSort') }

  it_behaves_like 'common sort values'

  it 'exposes all the existing EE issue sort values' do
    expect(described_class.values.keys).to include(
      *%w[WEIGHT_ASC WEIGHT_DESC PUBLISHED_ASC PUBLISHED_DESC SLA_DUE_AT_ASC SLA_DUE_AT_DESC
        BLOCKING_ISSUES_ASC BLOCKING_ISSUES_DESC HEALTH_STATUS_ASC HEALTH_STATUS_DESC STATUS_ASC STATUS_DESC]
    )
  end
end
