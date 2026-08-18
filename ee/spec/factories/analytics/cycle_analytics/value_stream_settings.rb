# frozen_string_literal: true

FactoryBot.define do
  factory :cycle_analytics_value_stream_setting, class: 'Analytics::CycleAnalytics::ValueStreamSetting' do
    value_stream { association(:cycle_analytics_value_stream) }
  end
end
