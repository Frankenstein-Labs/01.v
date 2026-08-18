# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting iterations', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:now) { Time.now }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:iteration_cadence1) do
    create(:iterations_cadence, group: group, active: true, duration_in_weeks: 1, title: 'one week iterations')
  end

  let_it_be(:iteration_cadence2) do
    create(:iterations_cadence, group: group, active: true, duration_in_weeks: 2, title: 'two week iterations')
  end

  let_it_be(:current_group_iteration) do
    create(:iteration, iterations_cadence: iteration_cadence1, title: 'one test', start_date: 1.day.ago,
      due_date: 1.week.from_now)
  end

  let_it_be(:upcoming_group_iteration) do
    create(:iteration, iterations_cadence: iteration_cadence2, start_date: 1.day.from_now, due_date: 2.days.from_now)
  end

  let_it_be(:closed_group_iteration) do
    create(:iteration, iterations_cadence: iteration_cadence1, start_date: 3.weeks.ago, due_date: 1.week.ago)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_group, :read_iteration] do
    let(:boundary_object) { group }
    let(:request) do
      post_graphql(iterations_query(group, "state: current"), token: { personal_access_token: pat })
    end
  end

  describe 'query for iterations by timeframe' do
    context 'without start date' do
      it 'returns error' do
        post_graphql(iterations_query(group, "timeframe: { end: \"#{3.days.ago.to_date}\" }"), current_user: user)

        expect(graphql_errors).to include(a_hash_including(
          'message' => "Argument 'start' on InputObject 'Timeframe' is required. Expected type Date!"
        ))
      end
    end

    context 'without end date' do
      it 'returns error' do
        post_graphql(iterations_query(group, "timeframe: { start: \"#{3.days.ago.to_date}\" }"), current_user: user)

        expect(graphql_errors).to include(a_hash_including(
          'message' => "Argument 'end' on InputObject 'Timeframe' is required. Expected type Date!"
        ))
      end
    end

    context 'with start and end date' do
      it 'does not have errors' do
        post_graphql(
          iterations_query(group,
            "timeframe: { start: \"#{3.days.ago.to_date}\", end: \"#{3.days.from_now.to_date}\" }"), current_user: user)

        expect(graphql_errors).to be_nil
      end
    end
  end

  describe 'query for iterations by cadence' do
    context 'with multiple cadences' do
      context 'searching by cadence title or iteration title and sorting by cadence and due date ASC' do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:past_iteration1) do
          create(:iteration, :with_due_date, iterations_cadence: iteration_cadence2, start_date: 4.weeks.ago)
        end

        let_it_be(:past_iteration2) do
          create(:iteration, :with_due_date, iterations_cadence: iteration_cadence2, start_date: 2.weeks.ago)
        end

        where(:search, :ordered_expected_iterations) do
          'two'       | lazy { [past_iteration1, past_iteration2, upcoming_group_iteration] }
          'iteration' | lazy do
            [closed_group_iteration, current_group_iteration, past_iteration1, past_iteration2,
              upcoming_group_iteration]
          end
        end

        with_them do
          let(:field_queries) { "search: \"#{search}\", in: [TITLE, CADENCE_TITLE], sort: CADENCE_AND_DUE_DATE_ASC" }

          it 'correctly returns ordered items' do
            post_graphql(iterations_query(group, field_queries), current_user: user)

            expect(actual_iterations).to eq(expected_iterations(ordered_expected_iterations))
          end
        end
      end

      it 'returns iterations' do
        post_graphql(
          iteration_cadence_query(group,
            [iteration_cadence1.to_global_id, iteration_cadence2.to_global_id]), current_user: user)

        expect_iterations_response(current_group_iteration, closed_group_iteration, upcoming_group_iteration)
      end
    end
  end

  describe 'query for iterations by state' do
    context 'with invalid state' do
      it 'returns empty iterations list' do
        post_graphql(iterations_query(group, "state: started"), current_user: user)

        expect(graphql_errors).to include(a_hash_including('message' =>
          "Argument 'state' on Field 'iterations' has an invalid value (started). Expected type 'IterationState'."))
      end
    end

    context 'with `current` state' do
      it 'returns `current` iteration' do
        post_graphql(iterations_query(group, "state: current"), current_user: user)

        expect_iterations_response(current_group_iteration)
      end
    end

    context 'with `closed` state' do
      it 'returns `closed` iteration' do
        post_graphql(iterations_query(group, "state: closed"), current_user: user)

        expect_iterations_response(closed_group_iteration)
      end

      context 'when sorting by cadence and due date DESC' do
        let_it_be(:another_closed_iteration) do
          create(:iteration, iterations_cadence: iteration_cadence1, start_date: 5.weeks.ago, due_date: 4.weeks.ago)
        end

        it 'returns `closed` iteration sorted by due date DESC' do
          post_graphql(iterations_query(group, "state: closed, sort: CADENCE_AND_DUE_DATE_DESC"), current_user: user)

          expect_iterations_response(another_closed_iteration, closed_group_iteration)
        end
      end
    end
  end

  describe 'N+1 query prevention' do
    let_it_be(:subgroup1) { create(:group, parent: group, maintainers: user) }
    let_it_be(:subgroup2) { create(:group, parent: group, maintainers: user) }

    let_it_be(:subgroup1_cadence) do
      create(
        :iterations_cadence,
        group: subgroup1,
        active: true,
        duration_in_weeks: 1,
        title: 'subgroup1 iterations'
      )
    end

    let_it_be(:subgroup1_iteration) do
      create(
        :iteration,
        iterations_cadence: subgroup1_cadence,
        start_date: 1.day.ago,
        due_date: 1.week.from_now
      )
    end

    it 'does not generate N+1 queries when requesting group and iteration cadence ' \
      'fields with descendants', :request_store, :use_sql_query_cache do
      query = <<~QUERY
        query {
          group(fullPath: "#{group.full_path}") {
            iterations(includeDescendants: true) {
              nodes {
                id
                group {
                  id
                  name
                }
                iterationCadence {
                  id
                  title
                }
              }
            }
          }
        }
      QUERY

      # Warm up cache with subgroup1
      post_graphql(query, current_user: user)

      control = ActiveRecord::QueryRecorder.new(skip_cached: true) do
        post_graphql(query, current_user: user)
      end

      # Add iterations to subgroup2
      subgroup2_cadence = create(
        :iterations_cadence,
        group: subgroup2,
        active: true,
        duration_in_weeks: 1,
        title: 'subgroup2 iterations'
      )

      create(:iteration, iterations_cadence: subgroup2_cadence, start_date: 2.weeks.from_now,
        due_date: 3.weeks.from_now)
      create(:iteration, iterations_cadence: subgroup2_cadence, start_date: 4.weeks.from_now,
        due_date: 5.weeks.from_now)

      expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
    end
  end

  def iteration_cadence_query(group, cadence_ids)
    cadence_ids_param = "[\"#{cadence_ids.join('","')}\"]"
    field_queries = "iterationCadenceIds: #{cadence_ids_param}"

    iterations_query(group, field_queries)
  end

  def iterations_query(group, field_queries)
    <<~QUERY
      query {
        group(fullPath: "#{group.full_path}") {
          id,
          iterations(#{field_queries}) {
            nodes {
              id
            }
          }
        }
      }
    QUERY
  end

  def actual_iterations
    graphql_data['group']['iterations']['nodes'].map { |iteration| iteration['id'] }
  end

  def expected_iterations(iterations)
    iterations.map { |iteration| iteration.to_global_id.to_s }
  end

  def expect_iterations_response(*iterations)
    expect(actual_iterations).to contain_exactly(*expected_iterations(iterations))
    expect(graphql_errors).to be_nil
  end
end
