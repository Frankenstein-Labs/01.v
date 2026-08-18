# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestReviewerFirstAssignedAt, feature_category: :value_stream_management do
  it_behaves_like 'value stream analytics event'

  it_behaves_like 'LEFT JOIN-able value stream analytics event' do
    let_it_be(:record_with_data) do
      create(:merge_request).tap do |mr|
        mr.metrics.update!(reviewer_first_assigned_at: Time.current)
      end
    end

    let_it_be(:record_without_data) { create(:merge_request) }
  end
end
