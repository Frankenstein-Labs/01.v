# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithDependencyProxyForMavenPackagesMetric, feature_category: :service_ping do
  let_it_be(:dependency_proxy_setting) { create(:dependency_proxy_packages_setting, :maven) }
  let_it_be(:disabled_proxy_setting) { create(:dependency_proxy_packages_setting, :disabled) }

  let(:expected_value) { 1 }

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' }
end
