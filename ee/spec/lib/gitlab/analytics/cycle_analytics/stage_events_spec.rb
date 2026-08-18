# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::StageEvents, feature_category: :value_stream_management do
  describe 'EE_ENUM_MAPPING' do
    let(:described_class) { EE::Gitlab::Analytics::CycleAnalytics::StageEvents }

    let(:expected_enum_mapping) do
      {
        described_class.event(:issue_closed) => 3,
        described_class.event(:issue_first_added_to_board) => 4,
        described_class.event(:issue_first_associated_with_milestone) => 5,
        described_class.event(:issue_last_edited) => 7,
        described_class.event(:issue_label_added) => 8,
        described_class.event(:issue_label_removed) => 9,
        described_class.event(:issue_first_assigned_at) => 11,
        described_class.event(:issue_first_added_to_iteration) => 12,
        described_class.event(:merge_request_closed) => 105,
        described_class.event(:merge_request_last_edited) => 106,
        described_class.event(:merge_request_label_added) => 107,
        described_class.event(:merge_request_label_removed) => 108,
        described_class.event(:merge_request_first_commit_at) => 109,
        described_class.event(:merge_request_first_assigned_at) => 110,
        described_class.event(:merge_request_reviewer_first_assigned_at) => 111,
        described_class.event(:merge_request_last_approved_at) => 112
      }.freeze
    end

    it 'contains the correct event to enum mappings' do
      expect(described_class::EE_ENUM_MAPPING).to eq(expected_enum_mapping)
    end

    it 'does not allow adding or removing mappings' do
      expect(described_class::EE_ENUM_MAPPING).to be_frozen
    end
  end

  describe 'EE_PAIRING_RULES' do
    let(:described_class) { EE::Gitlab::Analytics::CycleAnalytics::StageEvents }

    let(:expected_pairing_rules) do
      {
        described_class.event(:issue_label_added) => described_class.events(
          :issue_label_added,
          :issue_label_removed,
          :issue_closed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_label_removed) => described_class.events(
          :issue_closed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_created) => described_class.events(
          :issue_closed,
          :issue_first_added_to_board,
          :issue_first_associated_with_milestone,
          :issue_first_mentioned_in_commit,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_first_added_to_board) => described_class.events(
          :issue_closed,
          :issue_first_associated_with_milestone,
          :issue_first_mentioned_in_commit,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_first_associated_with_milestone) => described_class.events(
          :issue_closed,
          :issue_first_added_to_board,
          :issue_first_mentioned_in_commit,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_first_mentioned_in_commit) => described_class.events(
          :issue_closed,
          :issue_first_associated_with_milestone,
          :issue_first_added_to_board,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_assigned_at,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_closed) => described_class.events(
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed
        ),
        described_class.event(:issue_first_assigned_at) => described_class.events(
          :issue_closed,
          :issue_first_added_to_board,
          :issue_first_associated_with_milestone,
          :issue_first_mentioned_in_commit,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_added_to_iteration
        ),
        described_class.event(:issue_first_added_to_iteration) => described_class.events(
          :issue_closed,
          :issue_first_added_to_board,
          :issue_first_associated_with_milestone,
          :issue_first_mentioned_in_commit,
          :issue_last_edited,
          :issue_label_added,
          :issue_label_removed,
          :issue_first_assigned_at
        ),
        described_class.event(:merge_request_created) => described_class.events(
          :merge_request_closed,
          :merge_request_first_deployed_to_production,
          :merge_request_last_build_started,
          :merge_request_last_build_finished,
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_assigned_at,
          :merge_request_reviewer_first_assigned_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_first_assigned_at) => described_class.events(
          :merge_request_closed,
          :merge_request_last_build_started,
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_merged,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_reviewer_first_assigned_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_first_commit_at) => described_class.events(
          :merge_request_closed,
          :merge_request_first_deployed_to_production,
          :merge_request_last_build_started,
          :merge_request_last_build_finished,
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_merged,
          :merge_request_first_assigned_at,
          :merge_request_reviewer_first_assigned_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_first_deployed_to_production) => described_class.events(
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_commit_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_label_added) => described_class.events(
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_merged,
          :merge_request_first_assigned_at,
          :merge_request_reviewer_first_assigned_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_label_removed) => described_class.events(
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_assigned_at,
          :merge_request_reviewer_first_assigned_at,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_reviewer_first_assigned_at) => described_class.events(
          :merge_request_closed,
          :merge_request_last_build_started,
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_merged,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_last_approved_at
        ),
        described_class.event(:merge_request_closed) => described_class.events(
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_commit_at
        ),
        described_class.event(:merge_request_last_build_started) => described_class.events(
          :merge_request_closed,
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_merged,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_commit_at,
          :merge_request_reviewer_first_assigned_at
        ),
        described_class.event(:merge_request_last_build_finished) => described_class.events(
          :merge_request_closed,
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_merged,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_commit_at,
          :merge_request_reviewer_first_assigned_at
        ),
        described_class.event(:merge_request_merged) => described_class.events(
          :merge_request_closed,
          :merge_request_first_deployed_to_production,
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_first_commit_at
        ),
        described_class.event(:merge_request_last_approved_at) => described_class.events(
          :merge_request_merged,
          :merge_request_closed,
          :merge_request_last_edited,
          :merge_request_label_added,
          :merge_request_label_removed,
          :merge_request_last_build_started,
          :merge_request_last_build_finished
        )
      }.freeze
    end

    it 'contains the correct pairing rules' do
      expect(described_class::EE_PAIRING_RULES).to eq(expected_pairing_rules)
    end

    it 'ensures all referenced events exist in EE_EVENTS' do
      excluded_events = [
        Gitlab::Analytics::CycleAnalytics::StageEvents::IssueFirstMentionedInCommit,
        Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestFirstDeployedToProduction,
        Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestLastBuildStarted,
        Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestLastBuildFinished,
        Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestMerged
      ]

      referenced_events = described_class::EE_PAIRING_RULES.values.flatten.uniq - excluded_events

      referenced_events.each do |event|
        expect(described_class::EE_EVENTS).to include(event),
          "Event #{event} is referenced in pairing rules but not defined in EE_EVENTS"
      end
    end
  end
end
