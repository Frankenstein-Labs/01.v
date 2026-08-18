# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiMetrics::CodeReviewMetricsType, feature_category: :value_stream_management do
  it 'has the expected fields' do
    expected_fields = %w[
      encounter_duo_code_review_error_during_review_event_count
      find_no_issues_duo_code_review_after_review_event_count
      find_nothing_to_review_duo_code_review_on_mr_event_count
      post_comment_duo_code_review_on_diff_event_count
      react_thumbs_up_on_duo_code_review_comment_event_count
      react_thumbs_down_on_duo_code_review_comment_event_count
      request_review_duo_code_review_on_mr_by_author_event_count
      request_review_duo_code_review_on_mr_by_non_author_event_count
      excluded_files_from_duo_code_review_event_count
      publish_duo_code_review_comments_event_count
    ]

    expect(described_class).to have_graphql_fields(*expected_fields).only
  end
end
