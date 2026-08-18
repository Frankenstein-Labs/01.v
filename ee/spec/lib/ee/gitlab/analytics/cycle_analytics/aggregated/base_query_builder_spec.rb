# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::Aggregated::BaseQueryBuilder, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  let_it_be(:other_user, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:sub_group) { create(:group, parent: group, organization_id: group.organization_id) }
  let_it_be(:project_1, freeze: false) { create(:project, namespace: sub_group) }
  let_it_be(:project_2) { create(:project, namespace: sub_group) }

  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_project) { create(:project, namespace: other_group) }

  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let(:params) do
    {
      current_user: user,
      from: 1.year.ago.to_date,
      to: Date.today,
      sort: :end_event_timestamp,
      direction: :desc
    }
  end

  let(:query_builder) { described_class.new(stage: stage, params: params) }

  context 'when filtering issue based stages' do
    let_it_be(:iteration) { create(:iteration, group: group) }
    let_it_be(:epic) { create(:epic, group: group) }

    let_it_be(:issue_with_iteration, freeze: false) { create(:issue, project: project_1, assignees: [other_user]) }
    let_it_be(:issue_with_epic, freeze: false) do
      create(:issue, project: project_2, labels: [label], milestone: milestone)
    end

    let_it_be(:award_emoji) do
      create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: user, awardable: issue_with_epic)
    end

    let_it_be(:stage) do
      create(:cycle_analytics_stage,
        namespace: group,
        start_event_identifier: :issue_created,
        end_event_identifier: :issue_deployed_to_production
      )
    end

    let_it_be(:stage_event_1) do
      create(:cycle_analytics_issue_stage_event,
        stage_event_hash_id: stage.stage_event_hash_id,
        group_id: sub_group.id,
        project_id: project_1.id,
        start_event_timestamp: 4.weeks.ago,
        end_event_timestamp: 1.week.ago,
        sprint_id: iteration.id,
        issue_id: issue_with_iteration.id,
        duration_in_milliseconds: 3000
      )
    end

    let_it_be(:stage_event_2) do
      create(:cycle_analytics_issue_stage_event,
        stage_event_hash_id: stage.stage_event_hash_id,
        author_id: other_user.id,
        group_id: sub_group.id,
        project_id: project_2.id,
        start_event_timestamp: 2.weeks.ago,
        end_event_timestamp: 1.week.ago,
        milestone_id: milestone.id,
        weight: 5,
        issue_id: issue_with_epic.id,
        duration_in_milliseconds: 57000
      )
    end

    let_it_be(:stage_event_3) do
      create(:cycle_analytics_issue_stage_event,
        stage_event_hash_id: stage.stage_event_hash_id,
        group_id: other_group.id,
        project_id: other_project.id,
        issue_id: create(:issue, project: other_project).id,
        duration_in_milliseconds: 5000
      )
    end

    let_it_be(:epic_issue) { create(:epic_issue, epic: epic, issue: issue_with_epic) }

    subject(:issue_ids) { query_builder.build.pluck(:issue_id) }

    it 'looks up items within the group hierarchy' do
      expect(issue_ids).to match_array([stage_event_1.issue_id, stage_event_2.issue_id])
      expect(issue_ids).not_to include([stage_event_3.issue_id])
    end

    it 'accepts project_ids filter' do
      params[:project_ids] = [project_1.id, other_project.id]

      expect(issue_ids).to eq([stage_event_1.issue_id])
    end

    context 'when filtering by negated milestone title' do
      it 'filters by negated milestone_title' do
        params[:not] = { milestone_title: milestone.title }

        expect(issue_ids).not_to include(stage_event_2.issue_id)
      end

      context 'when negated and non-negated filters are present' do
        it 'filters by the non-negated filter' do
          params[:milestone_title] = milestone.title
          params[:not] = { milestone_title: milestone.title }

          expect(issue_ids).to eq([stage_event_2.issue_id])
        end
      end
    end

    context 'when filtering by author_username' do
      it 'filters by negated author_username' do
        params[:not] = { author_username: other_user.username }

        expect(issue_ids).not_to include(stage_event_2.issue_id)
      end
    end

    context 'when filtering by assignee_username' do
      it 'filters by negated assignee_username' do
        params[:not] = { assignee_username: other_user.username }

        expect(issue_ids).not_to include(stage_event_1.issue_id)
      end
    end

    context 'when filtering by label_name' do
      it 'filters by negated label_name' do
        params[:not] = { label_name: label.name }

        expect(issue_ids).not_to include(stage_event_2.issue_id)
      end
    end

    context 'when filtering by weight' do
      it 'filters by weight' do
        params[:weight] = 5

        expect(issue_ids).to eq([stage_event_2.issue_id])
      end

      context 'when no records matching the query' do
        it 'returns no results' do
          params[:weight] = 0

          expect(issue_ids).to eq([])
        end
      end

      context 'when the filter is negated' do
        it 'returns items without the given weight' do
          params[:not] = { weight: 5 }

          expect(issue_ids).to eq([stage_event_1.issue_id])
        end
      end
    end

    context 'when filtering by iteration_id' do
      it 'filters by iteration_id' do
        params[:iteration_id] = iteration.id

        expect(issue_ids).to eq([stage_event_1.issue_id])
      end

      context 'when no records matching the query' do
        it 'returns no results' do
          params[:iteration_id] = non_existing_record_id

          expect(issue_ids).to eq([])
        end
      end

      context 'when the filter is negated' do
        it 'returns items without the given iteration' do
          params[:not] = { iteration_id: iteration.id }

          expect(issue_ids).to eq([stage_event_2.issue_id])
        end
      end
    end

    context 'when filtering by epic_id' do
      it 'filters by epic_id' do
        params[:epic_id] = epic.id

        expect(issue_ids).to eq([stage_event_2.issue_id])
      end

      context 'when no records matching the query' do
        it 'returns no results' do
          params[:epic_id] = non_existing_record_id

          expect(issue_ids).to eq([])
        end
      end

      context 'when the filter is negated' do
        it 'returns items without the given epic' do
          params[:not] = { epic_id: epic.id }

          expect(issue_ids).to eq([stage_event_1.issue_id])
        end
      end
    end

    context 'when filtering by my_reaction_emoji' do
      it 'filters by my_reaction_emoji' do
        params[:my_reaction_emoji] = AwardEmoji::THUMBS_UP

        expect(issue_ids).to eq([stage_event_2.issue_id])
      end

      context 'when no records matching the query' do
        it 'returns no results' do
          params[:my_reaction_emoji] = 'unknown_emoji'

          expect(issue_ids).to eq([])
        end
      end

      context 'when the filter is negated' do
        it 'returns items without the given rection emoji' do
          params[:not] = { my_reaction_emoji: AwardEmoji::THUMBS_UP }

          expect(issue_ids).to eq([stage_event_1.issue_id])
        end
      end
    end

    describe '#build_sorted_query' do
      subject(:issue_ids) { query_builder.build_sorted_query.pluck(:issue_id) }

      it 'returns the items in order (by end_event)' do
        expect(issue_ids).to eq([stage_event_2.issue_id, stage_event_1.issue_id])
      end

      it 'returns the items in order (by db duration value)' do
        params[:sort] = :duration

        expect(issue_ids).to match_array([stage_event_2.issue_id, stage_event_1.issue_id])
      end

      it 'handles the project_ids filter' do
        params[:project_ids] = [project_1.id]

        expect(issue_ids).to eq([stage_event_1.issue_id])
      end
    end
  end

  context 'when filtering merge request based stages' do
    let_it_be(:merge_request_with_milestone, freeze: false) do
      create(:merge_request, :unique_branches,
        source_project: project_1,
        target_project: project_1,
        milestone: milestone,
        assignees: [other_user]
      )
    end

    let_it_be(:merge_request_with_label, freeze: false) do
      create(:merge_request, :unique_branches, source_project: project_1, target_project: project_1, labels: [label])
    end

    let_it_be(:award_emoji) do
      create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: user, awardable: merge_request_with_label)
    end

    let_it_be(:stage) do
      create(:cycle_analytics_stage,
        namespace: group,
        start_event_identifier: :merge_request_created,
        end_event_identifier: :merge_request_merged
      )
    end

    let_it_be(:stage_event_1) do
      create(:cycle_analytics_merge_request_stage_event,
        stage_event_hash_id: stage.stage_event_hash_id,
        group_id: sub_group.id,
        project_id: project_1.id,
        start_event_timestamp: 4.weeks.ago,
        end_event_timestamp: 1.week.ago,
        merge_request_id: merge_request_with_milestone.id,
        milestone_id: merge_request_with_milestone.milestone_id,
        duration_in_milliseconds: 3000
      )
    end

    let_it_be(:stage_event_2) do
      create(:cycle_analytics_merge_request_stage_event,
        stage_event_hash_id: stage.stage_event_hash_id,
        author_id: other_user.id,
        group_id: sub_group.id,
        project_id: project_2.id,
        start_event_timestamp: 2.weeks.ago,
        end_event_timestamp: 1.week.ago,
        merge_request_id: merge_request_with_label.id,
        duration_in_milliseconds: 57000
      )
    end

    subject(:merge_request_ids) { query_builder.build.pluck(:merge_request_id) }

    context 'when filtering by negated milestone title' do
      it 'filters by negated milestone_title' do
        params[:not] = { milestone_title: milestone.title }

        expect(merge_request_ids).not_to include(stage_event_1.merge_request_id)
      end

      context 'when negated and non-negated filters are present' do
        it 'filters by the non-negated filter' do
          params[:milestone_title] = milestone.title
          params[:not] = { milestone_title: milestone.title }

          expect(merge_request_ids).to eq([stage_event_1.merge_request_id])
        end
      end
    end

    context 'when filtering by my_reaction_emoji' do
      it 'filters by my_reaction_emoji' do
        params[:my_reaction_emoji] = AwardEmoji::THUMBS_UP

        expect(merge_request_ids).to eq([stage_event_2.merge_request_id])
      end

      context 'when no records matching the query' do
        it 'returns no results' do
          params[:my_reaction_emoji] = 'unknown_emoji'

          expect(merge_request_ids).to eq([])
        end
      end

      context 'when the filter is negated' do
        it 'returns items without the given rection emoji' do
          params[:not] = { my_reaction_emoji: AwardEmoji::THUMBS_UP }

          expect(merge_request_ids).to eq([stage_event_1.merge_request_id])
        end
      end
    end

    context 'when filtering by author_username' do
      it 'filters by negated author_username' do
        params[:not] = { author_username: other_user.username }

        expect(merge_request_ids).not_to include(stage_event_2.merge_request_id)
      end
    end

    context 'when filtering by assignee_username' do
      it 'filters by negated assignee_username' do
        params[:not] = { assignee_username: other_user.username }

        expect(merge_request_ids).not_to include(stage_event_1.merge_request_id)
      end
    end

    context 'when filtering by label_name' do
      it 'filters by negated label_name' do
        params[:not] = { label_name: label.name }

        expect(merge_request_ids).not_to include(stage_event_2.merge_request_id)
      end
    end
  end
end
