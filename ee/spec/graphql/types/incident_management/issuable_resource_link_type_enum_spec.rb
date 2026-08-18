# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::IncidentManagement::IssuableResourceLinkTypeEnum, feature_category: :incident_management do
  specify { expect(described_class.graphql_name).to eq('IssuableResourceLinkType') }

  it 'exposes all the existing issuable resource link types values' do
    expect(described_class.values.keys).to match_array(%w[general zoom slack pagerduty])
  end
end
