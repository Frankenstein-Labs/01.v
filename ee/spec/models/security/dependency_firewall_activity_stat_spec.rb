# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewallActivityStat, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:rule) { create(:dependency_firewall_policy_rule) }

  around do |example|
    freeze_time { example.run }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:dependency_firewall_policy_rule).optional }
    it { is_expected.to belong_to(:project).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:stat_time) }
    it { is_expected.to validate_presence_of(:outcome) }
    it { is_expected.to validate_numericality_of(:count).is_greater_than_or_equal_to(0) }

    it 'is invalid when an allowed row carries a rule_id' do
      stat = described_class.new(project: project, dependency_firewall_policy_rule: rule,
        outcome: :allowed, count: 1, stat_time: Time.current.beginning_of_hour)

      expect(stat).to be_invalid
      expect(stat.errors[:dependency_firewall_policy_rule_id]).to include('must be blank when outcome is allowed')
    end

    it 'is valid when a blocked row carries a rule_id' do
      stat = described_class.new(project: project, dependency_firewall_policy_rule: rule,
        outcome: :blocked, count: 1, stat_time: Time.current.beginning_of_hour)

      expect(stat).to be_valid
    end
  end

  describe 'factory' do
    it 'cannot be created with the default rule once the outcome is :allowed' do
      expect { create(:dependency_firewall_activity_stat, outcome: :allowed) }
        .to raise_error(ActiveRecord::RecordInvalid, /must be blank when outcome is allowed/)
    end

    it 'builds a valid rule-less allowed row via the :allowed trait' do
      stat = create(:dependency_firewall_activity_stat, :allowed)

      expect(stat).to have_attributes(outcome: 'allowed', dependency_firewall_policy_rule_id: nil)
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:outcome).with_values(blocked: 0, warned: 1, allowed: 2).with_prefix }
  end

  describe 'check_allowed_outcome_has_null_rule constraint' do
    let(:hour) { Time.current.beginning_of_hour }

    it 'rejects an allowed row with a rule_id via bulk_increment! (which bypasses model validation)' do
      expect do
        described_class.bulk_increment!([{
          project_id: project.id, dependency_firewall_policy_rule_id: rule.id,
          outcome: described_class.outcomes['allowed'], stat_time: hour, count: 1
        }])
      end.to raise_error(ActiveRecord::StatementInvalid, /check_allowed_outcome_has_null_rule/)
    end

    it 'permits an allowed row with a NULL rule_id' do
      expect do
        described_class.create!(project: project, dependency_firewall_policy_rule: nil,
          outcome: :allowed, count: 1, stat_time: hour)
      end.not_to raise_error
    end

    it 'permits a blocked or warned row that carries a rule_id' do
      expect do
        described_class.create!(project: project, dependency_firewall_policy_rule: rule,
          outcome: :blocked, count: 1, stat_time: hour)
      end.not_to raise_error
    end
  end

  describe 'scopes' do
    let_it_be(:other_project) { create(:project) }
    let_it_be(:other_rule) { create(:dependency_firewall_policy_rule) }

    let_it_be(:in_scope) do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, stat_time: 1.hour.ago.beginning_of_hour)
    end

    let_it_be(:other_project_stat) do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: other_project,
        outcome: :blocked, stat_time: 1.hour.ago.beginning_of_hour)
    end

    let_it_be(:other_rule_stat) do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: other_rule, project: project,
        outcome: :blocked, stat_time: 1.hour.ago.beginning_of_hour)
    end

    let_it_be(:old_stat) do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, stat_time: 2.days.ago.beginning_of_hour)
    end

    it '.for_rules limits to the given rule ids' do
      expect(described_class.for_rules([rule.id])).to contain_exactly(in_scope, other_project_stat, old_stat)
    end

    it '.for_projects limits to the given project ids' do
      expect(described_class.for_projects([project.id])).to contain_exactly(in_scope, other_rule_stat, old_stat)
    end

    it '.for_projects accepts a project relation and filters via WHERE EXISTS', :aggregate_failures do
      relation_scope = described_class.for_projects(Project.where(id: project.id))

      expect(relation_scope.to_sql).to include('EXISTS')
      expect(relation_scope).to contain_exactly(in_scope, other_rule_stat, old_stat)
    end

    it '.in_time_range limits to rows whose stat_time falls in the range' do
      expect(described_class.in_time_range(6.hours.ago..Time.current))
        .to contain_exactly(in_scope, other_project_stat, other_rule_stat)
    end
  end

  describe '.increment!', :clean_gitlab_redis_shared_state do
    def buffered_rows
      described_class.write_buffer.stage!
      described_class.write_buffer.staged_batch(10)
    end

    it 'buffers the increment instead of writing to the database' do
      expect do
        described_class.increment!(rule_id: rule.id, project_id: project.id, outcome: :blocked)
      end.not_to change { described_class.count }
    end

    it 'buffers the bucket recorded at increment time, truncated to the hour' do
      described_class.increment!(rule_id: rule.id, project_id: project.id, outcome: :blocked)

      expect(buffered_rows).to contain_exactly(
        hash_including(
          dependency_firewall_policy_rule_id: rule.id,
          project_id: project.id,
          outcome: described_class.outcomes['blocked'],
          count: 1,
          stat_time: be_like_time(Time.current.utc.beginning_of_hour)
        )
      )
    end

    it 'coalesces repeat activity into one buffered bucket' do
      3.times { described_class.increment!(rule_id: rule.id, project_id: project.id, outcome: :blocked) }

      expect(buffered_rows).to contain_exactly(hash_including(count: 3))
    end

    it 'buffers the bucket for the given time, truncated to that hour in UTC' do
      # A sub-hour-offset zone makes the UTC conversion load-bearing: without it the bucket would
      # start 30 minutes into the wrong hour.
      Time.use_zone('Asia/Kolkata') do
        time = Time.zone.parse('2026-08-05 10:15:00') # 04:45 UTC

        described_class.increment!(rule_id: rule.id, project_id: project.id, outcome: :blocked, time: time)

        expect(buffered_rows).to contain_exactly(
          hash_including(stat_time: be_like_time(Time.utc(2026, 8, 5, 4)))
        )
      end
    end

    it 'rejects a rule_id on an allowed outcome instead of buffering a bucket the flush cannot write' do
      expect do
        described_class.increment!(rule_id: rule.id, project_id: project.id, outcome: :allowed)
      end.to raise_error(ArgumentError, /allowed outcome cannot carry a rule_id/)
    end

    it 'buffers allowed outcomes with no rule under a NULL rule_id' do
      2.times { described_class.increment!(project_id: project.id, outcome: :allowed) }

      expect(buffered_rows).to contain_exactly(
        hash_including(dependency_firewall_policy_rule_id: nil, count: 2)
      )
    end
  end

  describe '.bulk_increment!' do
    def row(outcome: 'blocked', rule_id: rule.id, stat_time: Time.current.utc.beginning_of_hour, count: 1)
      {
        dependency_firewall_policy_rule_id: rule_id, project_id: project.id,
        stat_time: stat_time, outcome: described_class.outcomes[outcome], count: count
      }
    end

    it 'creates a row carrying the buffered total, bucketed to the hour', :aggregate_failures do
      expect { described_class.bulk_increment!([row(count: 4)]) }.to change { described_class.count }.by(1)

      expect(described_class.order(:id).last).to have_attributes(
        dependency_firewall_policy_rule_id: rule.id,
        project_id: project.id,
        outcome: 'blocked',
        count: 4,
        stat_time: be_like_time(Time.current.utc.beginning_of_hour)
      )
    end

    it 'adds to the existing bucket rather than inserting a new row', :aggregate_failures do
      described_class.bulk_increment!([row(count: 2)])
      described_class.bulk_increment!([row(count: 3)])

      expect(described_class.count).to eq(1)
      expect(described_class.order(:id).last.count).to eq(5)
    end

    it 'keeps separate buckets per outcome' do
      described_class.bulk_increment!([row(outcome: 'blocked'), row(outcome: 'warned')])

      expect(described_class.count).to eq(2)
    end

    it 'buckets activity in different hours into separate rows' do
      described_class.bulk_increment!([
        row(stat_time: 3.hours.ago.utc.beginning_of_hour), row
      ])

      expect(described_class.count).to eq(2)
    end

    it 'counts allowed outcomes with no rule (NULL rule_id) into a single bucket', :aggregate_failures do
      # Relies on NULLS NOT DISTINCT on i_dep_fw_activity_stats_unique: without it, each flush of
      # the NULL-rule allowed bucket would insert a duplicate row instead of incrementing.
      described_class.bulk_increment!([row(outcome: 'allowed', rule_id: nil, count: 2)])
      described_class.bulk_increment!([row(outcome: 'allowed', rule_id: nil, count: 3)])

      expect(described_class.count).to eq(1)
      expect(described_class.order(:id).last.count).to eq(5)
    end

    it 'writes an allowed bucket with the expected attributes' do
      described_class.bulk_increment!([row(outcome: 'allowed', rule_id: nil, count: 2)])

      expect(described_class.order(:id).last).to have_attributes(
        dependency_firewall_policy_rule_id: nil,
        outcome: 'allowed',
        count: 2
      )
    end

    it 'does nothing when given no rows' do
      expect { described_class.bulk_increment!([]) }.not_to change { described_class.count }
    end
  end

  describe '.outcome_totals' do
    before do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, count: 4)
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: nil, project: project,
        outcome: :allowed, count: 96)
    end

    it 'returns group-level totals per outcome, including NULL-rule allowed rows' do
      totals = described_class.outcome_totals(
        project_ids: [project.id], time_range: 1.day.ago..Time.current
      )

      expect(totals).to eq(blocked: 4, warned: 0, allowed: 96)
    end

    it 'excludes activity from projects outside the requested set' do
      other_project = create(:project)
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: other_project,
        outcome: :blocked, count: 50)

      totals = described_class.outcome_totals(
        project_ids: [project.id], time_range: 1.day.ago..Time.current
      )

      expect(totals).to eq(blocked: 4, warned: 0, allowed: 96)
    end

    it 'excludes activity outside the requested time window' do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, count: 50, stat_time: 2.days.ago.beginning_of_hour)

      totals = described_class.outcome_totals(
        project_ids: [project.id], time_range: 6.hours.ago..Time.current
      )

      expect(totals).to eq(blocked: 4, warned: 0, allowed: 96)
    end
  end

  describe '.activity_counts_by_rule' do
    let_it_be(:other_rule) { create(:dependency_firewall_policy_rule) }

    before do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, count: 5)
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :warned, count: 2)
    end

    subject(:counts) do
      described_class.activity_counts_by_rule(
        rule_ids: [rule.id, other_rule.id], project_ids: [project.id], time_range: 1.day.ago..Time.current
      )
    end

    it 'returns the blocked/warned hash per rule for rules with data' do
      expect(counts[rule.id]).to eq(blocked: 5, warned: 2)
    end

    it 'returns zeroed counts for a requested rule with no matching rows' do
      expect(counts[other_rule.id]).to eq(blocked: 0, warned: 0)
    end

    it 'excludes rows for rules outside the requested rule_ids' do
      unrequested_rule = create(:dependency_firewall_policy_rule)
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: unrequested_rule, project: project,
        outcome: :blocked, count: 99)

      expect(counts.keys).to contain_exactly(rule.id, other_rule.id)
    end

    it 'excludes rows from projects outside the requested set' do
      other_project = create(:project)
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: other_project,
        outcome: :blocked, count: 50)

      expect(counts[rule.id]).to eq(blocked: 5, warned: 2)
    end

    it 'excludes rows outside the requested time window' do
      create(:dependency_firewall_activity_stat, dependency_firewall_policy_rule: rule, project: project,
        outcome: :blocked, count: 99, stat_time: 2.days.ago.beginning_of_hour)

      windowed = described_class.activity_counts_by_rule(
        rule_ids: [rule.id], project_ids: [project.id], time_range: 6.hours.ago..Time.current
      )

      expect(windowed[rule.id]).to eq(blocked: 5, warned: 2)
    end
  end
end
