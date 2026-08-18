# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::RecommendReviewers::ReviewerDataBuilder, feature_category: :code_review_workflow do
  describe '.build' do
    subject(:data) { described_class.build(merge_request) }

    let_it_be_with_reload(:project) { create(:project) }
    let_it_be_with_refind(:approver) { create(:user, developer_of: project) }
    let_it_be_with_reload(:other_approver) { create(:user, developer_of: project) }
    let_it_be_with_reload(:current_reviewer) { create(:user, developer_of: project) }

    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project) do |mr|
        mr.reviewers << current_reviewer
      end
    end

    let_it_be_with_refind(:required_rule) do
      create(:code_owner_rule,
        merge_request: merge_request,
        name: '*.rb',
        section: 'codeowners',
        approvals_required: 1,
        users: [approver])
    end

    let_it_be(:optional_rule, freeze: false) do
      create(:approval_merge_request_rule,
        merge_request: merge_request,
        name: 'Optional Rule',
        rule_type: :regular,
        approvals_required: 0,
        users: [other_approver])
    end

    let_it_be(:protected_branch, freeze: false) do
      create(:protected_branch, project: project, name: merge_request.target_branch, code_owner_approval_required: true)
    end

    before do
      stub_licensed_features(
        merge_request_approvers: true,
        code_owners: true,
        code_owner_approval_required: true
      )
    end

    it 'includes current reviewers' do
      expect(data['current_reviewers']).to contain_exactly(
        { 'id' => current_reviewer.id, 'username' => current_reviewer.username }
      )
    end

    it 'excludes optional approval rules' do
      rule_names = data['approval_rules'].pluck('name')
      expect(rule_names).to contain_exactly('*.rb')
    end

    context 'with multiple required rules' do
      before do
        create(:code_owner_rule,
          merge_request: merge_request,
          name: '*.py',
          section: 'codeowners',
          approvals_required: 1,
          users: [other_approver])
      end

      it 'returns an entry per required rule' do
        rule_names = data['approval_rules'].pluck('name')
        expect(rule_names).to contain_exactly('*.rb', '*.py')
      end
    end

    it 'includes the rule name, section, and approvals_required' do
      expect(data['approval_rules'].first).to include(
        'name' => '*.rb',
        'section' => 'codeowners',
        'approvals_required' => 1
      )
    end

    it 'serializes eligible approvers with expected fields' do
      approver_data = data['approval_rules'].first['eligible_approvers'].first

      expect(approver_data).to include(
        'id' => approver.id,
        'username' => approver.username,
        'busy' => false,
        'status_emoji' => nil,
        'status_message' => nil,
        'pending_reviews' => 0,
        'local_time' => nil,
        'last_activity_on' => nil
      )
    end

    context 'when an approver has pending reviews' do
      let_it_be(:other_mr, freeze: false) do
        create(:merge_request, source_project: project, target_project: project, source_branch: 'other-branch') do |mr|
          mr.merge_request_reviewers.create!(reviewer: approver, state: :unreviewed)
        end
      end

      it 'returns the count of open reviews' do
        approver_data = data['approval_rules'].first['eligible_approvers'].first
        expect(approver_data['pending_reviews']).to eq(1)
      end
    end

    context 'when an approver was recently active' do
      let(:last_activity_date) { Date.new(2026, 4, 28) }

      before do
        approver.update!(last_activity_on: last_activity_date)
      end

      it 'returns the last activity date as ISO 8601' do
        approver_data = data['approval_rules'].first['eligible_approvers'].first
        expect(approver_data['last_activity_on']).to eq(last_activity_date.iso8601)
      end
    end

    context 'when an approver is busy' do
      before do
        create(:user_status, user: approver, availability: :busy, message: 'on call')
      end

      it 'sets busy to true and includes the message' do
        approver_data = data['approval_rules'].first['eligible_approvers'].first

        expect(approver_data['busy']).to be(true)
        expect(approver_data['status_message']).to eq('on call')
      end
    end

    context 'when an approver has a timezone preference' do
      before do
        approver.user_preference.update!(timezone: 'Australia/Melbourne')
      end

      context 'with AEST (no DST)' do
        around do |example|
          # May 1: Melbourne is UTC+10 (AEST), so 03:00 UTC -> 13:00 local
          travel_to(Time.utc(2026, 5, 1, 3, 0)) { example.run }
        end

        it 'computes the local time using the standard offset' do
          approver_data = data['approval_rules'].first['eligible_approvers'].first
          expect(approver_data['local_time']).to eq('13:00')
        end
      end

      context 'with AEDT (DST)' do
        around do |example|
          # January 1: Melbourne is UTC+11 (AEDT), so 03:00 UTC -> 14:00 local
          travel_to(Time.utc(2026, 1, 1, 3, 0)) { example.run }
        end

        it 'computes the local time using the daylight saving offset' do
          approver_data = data['approval_rules'].first['eligible_approvers'].first
          expect(approver_data['local_time']).to eq('14:00')
        end
      end
    end

    context 'when an approver has no timezone set' do
      before do
        approver.user_preference.update!(timezone: '')
      end

      it 'returns nil for local_time' do
        approver_data = data['approval_rules'].first['eligible_approvers'].first
        expect(approver_data['local_time']).to be_nil
      end
    end

    describe 'eligible approvers limit' do
      let(:limit) { 2 }

      before do
        stub_const("#{described_class}::MAX_APPROVERS_PER_RULE", limit)
      end

      context 'when at or below the limit' do
        it 'returns all approvers without sorting' do
          rule_data = data['approval_rules'].first
          expect(rule_data['eligible_approvers'].map { |a| a['id'] }).to contain_exactly(approver.id)
        end
      end

      context 'when over the limit' do
        let_it_be_with_refind(:extra_approver_a) { create(:user, developer_of: project) }
        let_it_be_with_refind(:extra_approver_b) { create(:user, developer_of: project) }

        before do
          required_rule.users << [extra_approver_a, extra_approver_b]
        end

        it 'caps the eligible approvers at the limit' do
          rule_data = data['approval_rules'].first
          expect(rule_data['eligible_approvers'].size).to eq(limit)
        end

        it 'prioritises non-busy approvers' do
          create(:user_status, user: extra_approver_a, availability: :busy)

          rule_data = data['approval_rules'].first
          approver_ids = rule_data['eligible_approvers'].map { |a| a['id'] }

          expect(approver_ids).not_to include(extra_approver_a.id)
        end

        it 'prioritises approvers with fewer pending reviews' do
          other_mr = create(:merge_request, source_project: project, source_branch: 'busy-branch')
          other_mr.merge_request_reviewers.create!(reviewer: extra_approver_a, state: :unreviewed)

          rule_data = data['approval_rules'].first
          approver_ids = rule_data['eligible_approvers'].map { |a| a['id'] }

          expect(approver_ids).not_to include(extra_approver_a.id)
        end

        it 'prioritises non-busy first, then by pending reviews' do
          # 3 candidates (limit = 2):.
          # - approver: not busy, 0 pending          -> kept
          # - extra_approver_a: not busy, 1 pending  -> kept (non-busy beats busy)
          # - extra_approver_b: busy, 0 pending      -> excluded
          create(:user_status, user: extra_approver_b, availability: :busy)
          other_mr = create(:merge_request, source_project: project, source_branch: 'busy-branch')
          other_mr.merge_request_reviewers.create!(reviewer: extra_approver_a, state: :unreviewed)

          rule_data = data['approval_rules'].first
          approver_ids = rule_data['eligible_approvers'].map { |a| a['id'] }

          expect(approver_ids).to contain_exactly(approver.id, extra_approver_a.id)
        end
      end
    end

    describe 'query performance', :use_clean_rails_memory_store_caching do
      def build_for(mr)
        described_class.build(MergeRequest.find(mr.id))
      end

      it 'does not produce N+1 queries when there are many approvers (warm cache)' do
        approver.review_requested_open_merge_requests_count

        control = ActiveRecord::QueryRecorder.new { build_for(merge_request) }

        extra_approvers = create_list(:user, 3, developer_of: project)
        extra_approvers.each do |u|
          create(:user_status, user: u)
          u.user_preference.update!(timezone: 'Australia/Melbourne')
          u.review_requested_open_merge_requests_count
        end
        required_rule.users << extra_approvers

        expect { build_for(merge_request) }.not_to exceed_all_query_limit(control).allow_skip_cache_inconsistency
      end
    end

    context 'when the only required rule is the synthetic any_approver rule' do
      let_it_be(:any_project, freeze: false) { create(:project, :repository) }
      let_it_be(:any_author) { create(:user, developer_of: any_project) }
      let_it_be(:any_developer) { create(:user, developer_of: any_project) }
      let_it_be(:any_maintainer) { create(:user, maintainer_of: any_project) }
      let_it_be(:any_reporter) { create(:user, reporter_of: any_project) }

      let_it_be_with_refind(:any_merge_request) do
        create(:merge_request, source_project: any_project, target_project: any_project, author: any_author)
      end

      let_it_be(:any_approver_rule) do
        create(:any_approver_rule, merge_request: any_merge_request, approvals_required: 1)
      end

      subject(:data) { described_class.build(any_merge_request) }

      it 'surfaces the "All Members" rule with the members that can approve', :aggregate_failures do
        rule = data['approval_rules'].find { |r| r['name'] == 'All Members' }

        expect(rule['approvals_required']).to eq(1)
        expect(rule['eligible_approvers'].pluck('id')).to include(any_developer.id, any_maintainer.id)
      end

      it 'excludes the author and the members that cannot approve' do
        approver_ids = data['approval_rules'].first['eligible_approvers'].pluck('id')

        expect(approver_ids).not_to include(any_author.id, any_reporter.id)
      end

      context 'when a bot or service account is a project member' do
        let_it_be(:project_bot) { create(:user, :project_bot, developer_of: any_project) }
        let_it_be(:service_account) { create(:user, :service_account, developer_of: any_project) }

        it 'excludes bots and service accounts' do
          approver_ids = data['approval_rules'].first['eligible_approvers'].pluck('id')

          expect(approver_ids).not_to include(project_bot.id, service_account.id)
        end
      end

      context 'when only maintainers can merge into the target branch' do
        before do
          create(:protected_branch, :maintainers_can_merge, :no_one_can_push,
            project: any_project, name: any_merge_request.target_branch)
        end

        it 'narrows the candidates to the members that can merge', :aggregate_failures do
          approver_ids = data['approval_rules'].first['eligible_approvers'].pluck('id')

          expect(approver_ids).to include(any_maintainer.id)
          expect(approver_ids).not_to include(any_developer.id)
        end
      end

      context 'when there are more candidates than the limit' do
        before do
          stub_const("#{described_class}::MAX_APPROVERS_PER_RULE", 1)
        end

        it 'caps the candidates at the limit' do
          approver_ids = data['approval_rules'].first['eligible_approvers'].pluck('id')

          expect(approver_ids.size).to eq(1)
        end
      end
    end
  end
end
