# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::DuoAvailabilityMetric, feature_category: :plan_provisioning do
  [:default_on, :default_off, :never_on].each do |setting_value|
    context "when duo_features_enabled is #{setting_value}" do
      before do
        stub_application_setting(duo_features_enabled: setting_value == :default_on,
          lock_duo_features_enabled: setting_value == :never_on)
      end

      it_behaves_like 'a correct instrumented metric value', {} do
        let(:expected_value) { setting_value.to_s }
      end
    end
  end
end
