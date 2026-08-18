# frozen_string_literal: true

RSpec.shared_context 'with value stream analytics flow metrics common data' do
  let(:model_to_aggregate) { Issue }

  let_it_be(:milestone, freeze: false) { create(:milestone, group: group) }
  let_it_be(:label, freeze: false) { create(:group_label, group: group) }

  let_it_be(:author, freeze: false) { create(:user) }
  let_it_be(:assignee, freeze: false) { create(:user) }

  before do
    Analytics::CycleAnalytics::DataLoaderService.new(namespace: group, model: model_to_aggregate).execute
  end
end

RSpec.shared_examples 'value stream analytics flow metrics leadTime examples' do
  include_context 'with value stream analytics flow metrics common data'

  let_it_be(:issue1, freeze: false) do
    create(:issue, project: project1, author: author, created_at: 17.days.ago, closed_at: 12.days.ago)
  end

  let_it_be(:issue2, freeze: false) do
    create(:issue, project: project2, author: author, created_at: 16.days.ago, closed_at: 13.days.ago)
  end

  let_it_be(:issue3, freeze: false) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago,
      closed_at: 11.days.ago)
  end

  let_it_be(:issue4, freeze: false) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      created_at: 20.days.ago,
      closed_at: 15.days.ago)
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            leadTime(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'leadTime')
  end

  it 'returns the correct value' do
    expect(result).to match(a_hash_including({
      'identifier' => 'lead_time',
      'unit' => n_('day', 'days', 4),
      'value' => 4,
      'title' => _('Lead time'),
      'links' => [
        { 'label' => s_('ValueStreamAnalytics|Dashboard'), 'url' => match(/issues_analytics/) },
        { 'label' => s_('ValueStreamAnalytics|Learn more'), 'url' => match(/definitions/) }
      ]
    }))
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when assignees is null' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: nil,
        from: 21.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'treats as no filter on assignees' do
      expect(result).to match(a_hash_including({ 'value' => 4.0 }))
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => nil }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 3 }))
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics cycleTime examples' do
  include_context 'with value stream analytics flow metrics common data'

  let_it_be(:issue1, freeze: false) do
    create(:issue, project: project1, author: author, closed_at: 12.days.ago).tap do |issue|
      issue.metrics.update!(first_mentioned_in_commit_at: 17.days.ago)
    end
  end

  let_it_be(:issue2, freeze: false) do
    create(:issue, project: project2, author: author, closed_at: 13.days.ago).tap do |issue|
      issue.metrics.update!(first_mentioned_in_commit_at: 16.days.ago)
    end
  end

  let_it_be(:issue3, freeze: false) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      closed_at: 11.days.ago).tap do |issue|
        issue.metrics.update!(first_mentioned_in_commit_at: 14.days.ago)
      end
  end

  let_it_be(:issue4, freeze: false) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      closed_at: 15.days.ago).tap do |issue|
        issue.metrics.update!(first_mentioned_in_commit_at: 20.days.ago)
      end
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            cycleTime(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'cycleTime')
  end

  it 'returns the correct value' do
    expect(result).to eq({
      'identifier' => 'cycle_time',
      'unit' => n_('day', 'days', 4),
      'value' => 4,
      'title' => _('Cycle time'),
      'links' => []
    })
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => nil }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 3 }))
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics issuesCompleted examples' do
  include_context 'with value stream analytics flow metrics common data'
  let_it_be(:epic, freeze: false) { create(:epic, group: group) }

  # we don't care about opened date, only closed date.
  let_it_be(:issue1, freeze: false) do
    create(:issue, project: project1, author: author, created_at: 17.days.ago, closed_at: 12.days.ago, weight: 4)
  end

  let_it_be(:issue2, freeze: false) do
    create(:issue, project: project2, author: author, created_at: 16.days.ago, closed_at: 13.days.ago)
  end

  let_it_be(:issue3, freeze: false) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago,
      closed_at: 11.days.ago)
  end

  let_it_be(:issue4, freeze: false) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      weight: 4,
      assignees: [assignee],
      created_at: 20.days.ago,
      closed_at: 15.days.ago)
  end

  let_it_be(:epic_issue, freeze: false) { create(:epic_issue, epic: epic, issue: issue3) }

  before_all do
    create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: current_user, awardable: issue2)
    create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: current_user, awardable: issue3)
    create(:award_emoji, name: AwardEmoji::THUMBS_UP, user: current_user, awardable: issue4)
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!, $weight: Int, $notAssignee: [String!], $notLabel: [String!], $notMyReactionEmoji: String, $epicId: ID) {
        #{context}(fullPath: $path) {
          flowMetrics {
            issuesCompletedCount(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to, weight: $weight, epicId: $epicId, not: { assigneeUsernames: $notAssignee, labelNames: $notLabel, myReactionEmoji: $notMyReactionEmoji }) {
              value
              unit
              identifier
              title
              links {
                label
                url
              }
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'issuesCompletedCount')
  end

  it 'returns the correct value' do
    expect(result).to match(a_hash_including({
      'identifier' => 'issues_completed',
      'unit' => n_('issue', 'issues', 4),
      'value' => 4,
      'title' => _('Issues Completed'),
      'links' => [
        { 'label' => s_('ValueStreamAnalytics|Dashboard'), 'url' => match(/issues_analytics/) },
        { 'label' => s_('ValueStreamAnalytics|Learn more'), 'url' => match(/definitions/) }
      ]
    }))
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end

  context 'when outside of the date range' do
    let(:variables) do
      {
        path: full_path,
        from: 30.days.ago.iso8601,
        to: 25.days.ago.iso8601
      }
    end

    it 'returns 0 count' do
      expect(result).to match(a_hash_including({ 'value' => 0.0 }))
    end
  end

  context 'when filtering by weight and negated assignee' do
    let(:variables) do
      {
        path: full_path,
        from: 21.days.ago.iso8601,
        to: 10.days.ago.iso8601,
        weight: 4,
        notAssignee: [assignee.username]
      }
    end

    it 'returns 1 count' do
      expect(result).to match(a_hash_including({ 'value' => 1 }))
    end
  end

  context 'when filtering by negated label' do
    let(:variables) do
      {
        path: full_path,
        from: 21.days.ago.iso8601,
        to: 10.days.ago.iso8601,
        notLabel: [label.title]
      }
    end

    it 'returns 2 count' do
      expect(result).to match(a_hash_including({ 'value' => 2 }))
    end
  end

  context 'when filtering by negated reaction emoji' do
    let(:variables) do
      {
        path: full_path,
        from: 21.days.ago.iso8601,
        to: 10.days.ago.iso8601,
        notMyReactionEmoji: AwardEmoji::THUMBS_UP
      }
    end

    it 'returns 1 count' do
      expect(result).to match(a_hash_including({ 'value' => 1 }))
    end
  end

  context 'when filtering by epic' do
    let(:variables) do
      {
        path: full_path,
        from: 21.days.ago.iso8601,
        to: 10.days.ago.iso8601,
        epicId: epic.id
      }
    end

    it 'returns 1 count' do
      expect(result).to match(a_hash_including({ 'value' => 1 }))
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to match(a_hash_including({ 'value' => 1.0 }))
    end
  end
end

RSpec.shared_examples 'value stream analytics flow metrics timeToMerge examples' do
  include_context 'with value stream analytics flow metrics common data'
  let(:model_to_aggregate) { MergeRequest }

  let_it_be(:merge_request1, freeze: false) do
    create(:merge_request, :unique_branches, source_project: project1, author: author,
      created_at: 17.days.ago).tap do |mr|
      mr.metrics.update!(merged_at: 12.days.ago)
    end
  end

  let_it_be(:merge_request2, freeze: false) do
    create(:merge_request, :unique_branches, source_project: project1, created_at: 16.days.ago).tap do |issue|
      issue.metrics.update!(merged_at: 13.days.ago)
    end
  end

  let(:query) do
    <<~QUERY
      query($path: ID!, $authorUsername: String, $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            timeToMerge(authorUsername: $authorUsername, from: $from, to: $to) {
              value
              unit
              identifier
              title
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 21.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'timeToMerge')
  end

  it 'returns the correct value' do
    expect(result).to eq({
      'identifier' => 'time_to_merge',
      'unit' => n_('day', 'days', 4),
      'value' => 4,
      'title' => _('Time to Merge')
    })
  end

  context 'when author filter is given' do
    before do
      variables[:authorUsername] = author.username
    end

    it 'returns value only for the first MR' do
      expect(result).to match(a_hash_including({ 'value' => 5 }))
    end
  end
end
