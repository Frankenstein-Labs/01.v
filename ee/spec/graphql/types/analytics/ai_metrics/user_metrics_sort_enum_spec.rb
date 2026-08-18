# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::UserMetricsSortEnum, feature_category: :value_stream_management do
  specify { expect(described_class.graphql_name).to eq('AiUserMetricsSort') }

  specify { expect(described_class.description).to eq('Values for sorting AI user metrics.') }

  it 'generates feature-level sort values with correct attributes' do
    Gitlab::Tracking::AiTracking.registered_features.each do |feature|
      feature_name = feature.to_s.upcase
      feature_titleized = feature.to_s.titleize

      expect(described_class.values).to include(
        "#{feature_name}_TOTAL_COUNT_DESC" => have_attributes(
          description: "#{feature_titleized} total event count in descending order.",
          value: { field: feature, direction: :desc }
        ),
        "#{feature_name}_TOTAL_COUNT_ASC" => have_attributes(
          description: "#{feature_titleized} total event count in ascending order.",
          value: { field: feature, direction: :asc }
        )
      )
    end
  end

  it 'dynamically generates sort values for each registered event within features' do
    Gitlab::Tracking::AiTracking.registered_features.each do |feature|
      Gitlab::Tracking::AiTracking.registered_events(feature).each_key do |event_name|
        event_name_upcase = event_name.to_s.upcase
        event_name_titleized = event_name.to_s.titleize

        expect(described_class.values).to include(
          "#{event_name_upcase}_DESC" => have_attributes(
            description: "#{event_name_titleized} event count in descending order.",
            value: { field: event_name, direction: :desc }
          ),
          "#{event_name_upcase}_ASC" => have_attributes(
            description: "#{event_name_titleized} event count in ascending order.",
            value: { field: event_name, direction: :asc }
          )
        )
      end
    end
  end
end
