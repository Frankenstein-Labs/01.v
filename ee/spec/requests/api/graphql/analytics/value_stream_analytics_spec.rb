# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Project|Group).value_stream_analytics', :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be_with_refind(:current_user) { create(:user) }

  let(:query) do
    <<~QUERY
      query($fullPath: ID!) {
        #{resource_type}(fullPath: $fullPath) {
          valueStreamAnalytics {
            aggregationStatus {
              enabled
              lastUpdateAt
              estimatedNextUpdateAt
            }
          }
        }
      }
    QUERY
  end

  shared_examples 'value stream analytics query' do
    def run_query
      post_graphql(query, current_user: current_user, variables: { fullPath: resource.full_path })
    end

    context 'when the feature is not licensed' do
      before do
        resource.add_reporter(current_user)
      end

      it 'return nil for valueStreamAnalytics' do
        run_query

        expect(graphql_data_at(resource_type, :valueStremAnalytics)).to be_nil
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(
          cycle_analytics_for_projects: true,
          cycle_analytics_for_groups: true
        )
      end

      context 'when the user is authorized' do
        before do
          resource.add_reporter(current_user)
        end

        context 'when aggregation record does not exist' do
          it 'return nil for aggregationStatus' do
            run_query

            expect(graphql_data_at(resource_type, :valueStremAnalytics, :aggregationStatus)).to be_nil
          end
        end

        context 'when the aggregation record exists' do
          let!(:aggregation) do
            create(:cycle_analytics_aggregation, namespace: resource.root_ancestor,
              last_incremental_run_at: Time.current)
          end

          it 'returns the aggregation status' do
            run_query

            expect(graphql_data_at(resource_type, 'valueStreamAnalytics', 'aggregationStatus')).to match({
              'enabled' => true,
              'lastUpdateAt' => aggregation.last_incremental_run_at.iso8601,
              'estimatedNextUpdateAt' => aggregation.estimated_next_run_at.iso8601
            })
          end
        end
      end

      context 'when the user is not authorized' do
        it 'returns nil for the resource' do
          run_query

          expect(graphql_data_at(resource_type, :valueStremAnalytics)).to be_nil
        end
      end
    end
  end

  context 'for projects' do
    let(:resource_type) { 'project' }

    let_it_be(:resource) { create(:project, group: create(:group)) }

    it_behaves_like 'value stream analytics query'
  end

  context 'for groups' do
    let(:resource_type) { 'group' }

    let_it_be(:resource) { create(:group) }

    it_behaves_like 'value stream analytics query'
  end
end
