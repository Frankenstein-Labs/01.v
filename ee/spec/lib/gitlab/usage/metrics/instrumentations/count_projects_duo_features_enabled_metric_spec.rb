# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsDuoFeaturesEnabledMetric, feature_category: :service_ping do
  context 'when there are no duo features enabled projects' do
    let(:expected_value) { 0 }

    let_it_be(:project) do
      create(:project, project_setting: create(:project_setting, duo_features_enabled: false))
    end

    it_behaves_like 'a correct instrumented metric value',
      { time_frame: 'none' }
  end

  context 'when there are duo features enabled projects' do
    let(:expected_value) { 1 }

    let_it_be(:project) do
      create(:project, project_setting: create(:project_setting, duo_features_enabled: true))
    end

    it_behaves_like 'a correct instrumented metric value',
      { time_frame: 'none' }
  end
end
