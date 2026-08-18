# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectSetting'], feature_category: :duo_code_review do
  it 'includes project setting fields' do
    expected_fields = %w[
      ai_audit_events_storage_enabled
      duo_features_enabled
      project
      web_based_commit_signing_enabled
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class.graphql_name).to eq('ProjectSetting') }
end
