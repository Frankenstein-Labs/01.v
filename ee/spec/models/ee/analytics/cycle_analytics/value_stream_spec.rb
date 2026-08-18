# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ValueStream, feature_category: :value_stream_management do
  describe 'associations' do
    it { is_expected.to have_one(:setting) }
  end

  it 'persists settings with nested attributes' do
    value_stream =
      build(:cycle_analytics_value_stream,
        name: 'test',
        setting_attributes: { project_ids_filter: [1, 2] }
      )

    value_stream.save!

    expect(value_stream).to be_persisted
    expect(value_stream.setting).to be_persisted
    expect(value_stream.setting[:project_ids_filter]).to eq([1, 2])
  end
end
