# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithSecretPushProtectionEnabledMetric, feature_category: :service_ping do
  let(:expected_value) { 3 }

  before do
    3.times do
      create(:project).security_setting.update!(secret_push_protection_enabled: true)
    end
    create(:project)
  end

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' }
end
