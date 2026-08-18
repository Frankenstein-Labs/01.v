# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::BaseIntegrationsMetric,
  feature_category: :team_planning do
  it "raises no exceptions when options use a type disabled in settings" do
    stub_application_setting(allow_all_integrations: false)
    stub_application_setting(allowed_integrations: ['apple_app_store'])
    stub_licensed_features(integrations_allow_list: true)

    expect do
      described_class.new(options: { type: 'pivotaltracker' }, time_frame: 'all')
    end.not_to raise_error
  end
end
