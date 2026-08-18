# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::SecretsManagement::CountEnrolledNamespacesMetric,
  feature_category: :secrets_management do
  before_all do
    create(:secrets_manager_namespace_enrollment)
    create(:secrets_manager_namespace_enrollment)
  end

  context 'with all time frame' do
    let(:expected_value) { 2 }
    let(:expected_query) do
      'SELECT COUNT("secrets_manager_namespace_enrollments"."id") FROM "secrets_manager_namespace_enrollments"'
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
  end
end
