# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::GitlabSubscriptions::LicensedFeatureEnum, feature_category: :subscription_management do
  specify { expect(described_class.graphql_name).to eq('LicensedFeature') }

  it 'includes only non-global licensed features' do
    expected_features = (
      ::GitlabSubscriptions::Features::ALL_FEATURES -
      ::GitlabSubscriptions::Features::GLOBAL_FEATURES
    ).uniq.map { |f| f.to_s.upcase }

    expect(described_class.values.keys).to match_array(expected_features)
  end

  it 'does not include global features' do
    global_feature_keys = ::GitlabSubscriptions::Features::GLOBAL_FEATURES.map { |f| f.to_s.upcase }

    expect(described_class.values.keys).not_to include(*global_feature_keys)
  end

  it 'maps enum values to feature name strings' do
    expect(described_class.values['EPICS'].value).to eq('epics')
    expect(described_class.values['SECURITY_DASHBOARD'].value).to eq('security_dashboard')
  end
end
