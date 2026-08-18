# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciMinutesProjectMonthlyUsage', feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:user_namespace) { create(:namespace) }
  let_it_be(:user) { user_namespace.owner }
  let_it_be(:user_project) { create(:project, name: 'Project 1', namespace: user_namespace) }
  let_it_be_with_refind(:group) { create(:group, :public, name: 'test') }
  let_it_be(:group_project) { create(:project, name: 'Group Project', namespace: group) }

  let_it_be(:may_date) { Date.new(2021, 5, 1) }
  let_it_be(:april_date) { Date.new(2021, 4, 1) }

  before_all do
    create(:ci_project_monthly_usage,
      project: user_project,
      amount_used: 40,
      shared_runners_duration: 80,
      date: may_date)

    create(:ci_project_monthly_usage,
      project: group_project,
      amount_used: 120,
      shared_runners_duration: 240,
      date: may_date)
  end

  subject(:result) { post_graphql(query, current_user: user) }

  def query_for(namespace: nil, date: may_date)
    namespace_argument = namespace ? %(namespaceId: "#{namespace.to_global_id}") : ''
    date_argument = date ? %(date: "#{date.iso8601}") : ''
    arguments = [namespace_argument, date_argument].reject(&:empty?).join(', ')
    arguments = "(#{arguments})" unless arguments.empty?

    <<-QUERY
      {
        ciMinutesProjectMonthlyUsage#{arguments} {
          nodes {
            minutes
            sharedRunnersDuration
            project {
              name
            }
          }
        }
      }
    QUERY
  end

  context 'when no namespace_id is provided' do
    let(:query) { query_for(date: may_date) }

    it 'returns project usages for the current user namespace and given month' do
      result

      project_usage = graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)

      expect(project_usage).to contain_exactly(
        {
          'minutes' => 40,
          'sharedRunnersDuration' => 80,
          'project' => { 'name' => 'Project 1' }
        }
      )
    end

    context 'when date is omitted' do
      let(:query) { query_for(date: nil) }

      it 'defaults to the current month' do
        travel_to(Date.new(2026, 6, 15)) do
          create(:ci_project_monthly_usage,
            project: user_project,
            amount_used: 25,
            shared_runners_duration: 55,
            date: Date.new(2026, 6, 1))

          result

          project_usage = graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)

          expect(project_usage).to contain_exactly(
            {
              'minutes' => 25,
              'sharedRunnersDuration' => 55,
              'project' => { 'name' => 'Project 1' }
            }
          )
        end
      end
    end

    it 'does not create N+1 queries' do
      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }
      expect(graphql_errors).to be_nil

      project_2 = create(:project, name: 'Project 2', namespace: user_namespace)
      create(:ci_project_monthly_usage, project: project_2, amount_used: 50, date: may_date)

      expect do
        post_graphql(query, current_user: user)
      end.not_to exceed_query_limit(control)
      expect(graphql_errors).to be_nil
    end
  end

  context 'when namespace_id is provided' do
    let(:query) { query_for(namespace: group, date: may_date) }

    context 'when group is root' do
      context 'when user is an owner' do
        before_all do
          group.add_owner(user)
        end

        it 'returns project usages for the given namespace and date' do
          result

          project_usage = graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)

          expect(project_usage).to contain_exactly(
            {
              'minutes' => 120,
              'sharedRunnersDuration' => 240,
              'project' => { 'name' => 'Group Project' }
            }
          )
        end

        context 'when no NamespaceMonthlyUsage row exists for the requested month' do
          # This is the regression #595154 closes: project usage must be visible
          # even when a namespace-level row was never lazily created.
          it 'still returns project usages' do
            expect(Ci::Minutes::NamespaceMonthlyUsage.by_namespace_and_date(group, may_date)).to be_empty

            result

            project_usage = graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)
            expect(project_usage).to contain_exactly(
              a_hash_including('project' => { 'name' => 'Group Project' })
            )
          end
        end

        context 'when a different month is requested' do
          let(:query) { query_for(namespace: group, date: april_date) }

          it 'returns no usages' do
            result

            expect(graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)).to be_empty
          end
        end
      end

      context 'when user is not an owner' do
        before_all do
          group.add_developer(user)
        end

        it 'does not return usage data' do
          result

          expect(graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)).to be_empty
        end
      end
    end

    context 'when group is a subgroup' do
      let(:subgroup) { create(:group, :public, parent: group) }
      let(:query) { query_for(namespace: subgroup, date: may_date) }

      before do
        subgroup.add_owner(user)
      end

      it 'does not return usage data' do
        result

        expect(graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)).to be_empty
      end
    end
  end

  context 'when the user is not authenticated' do
    subject(:result) { post_graphql(query, current_user: nil) }

    context 'when no namespace_id is provided' do
      let(:query) { query_for(date: may_date) }

      it 'returns an empty result without errors' do
        result

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)).to be_empty
      end
    end

    context 'when namespace_id is provided' do
      let(:query) { query_for(namespace: group, date: may_date) }

      it 'returns an empty result without errors' do
        result

        expect(graphql_errors).to be_nil
        expect(graphql_data_at(:ci_minutes_project_monthly_usage, :nodes)).to be_empty
      end
    end
  end
end
