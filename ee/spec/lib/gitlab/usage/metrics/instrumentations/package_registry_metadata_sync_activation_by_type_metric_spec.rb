# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::PackageRegistryMetadataSyncActivationByTypeMetric, feature_category: :software_composition_analysis do
  let(:expected_value) { PackageMetadata::SyncConfiguration.permitted_purl_types }
  let(:expected_query) { expected_value }

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
end
