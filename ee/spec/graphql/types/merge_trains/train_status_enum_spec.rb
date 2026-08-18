# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MergeTrains::TrainStatusEnum, feature_category: :merge_trains do
  let(:expected_values) do
    ::MergeTrains::Train::STATUSES.map { |_, v| v.upcase }
  end

  subject { described_class.values.keys }

  it { is_expected.to match_array(expected_values) }
end
