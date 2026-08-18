# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Export work items', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:work_item) { create(:work_item, project: project) }
  let_it_be(:iteration) { create(:iteration, group: project.group) }

  let(:mutation) { graphql_mutation(:workItemsCsvExport, input) }
  let(:mutation_response) { graphql_mutation_response(:work_items_csv_export) }

  context 'when user has permissions to export work items with EE filters' do
    let(:current_user) { guest }
    let(:input) do
      {
        'selectedFields' => %w[TITLE DESCRIPTION AUTHOR TYPE AUTHOR_USERNAME CREATED_AT],
        'projectPath' => project.full_path,
        'healthStatusFilter' => 'onTrack',
        'iterationWildcardId' => 'ANY',
        'iterationCadenceId' => iteration.iterations_cadence.to_gid,
        'not' => { 'iterationId' => iteration.to_gid },
        'weightWildcardId' => 'ANY',
        'status' => { 'name' => 'To do' }
      }
    end

    it 'schedules export job with given arguments', :aggregate_failures do
      expected_arguments = {
        selected_fields: ['title', 'description', 'author', 'type', 'author username', 'created at'],
        health_status: 'on_track',
        iteration_id: 'ANY',
        iteration_cadence_id: [iteration.iterations_cadence_id.to_s],
        not: { iteration_id: [iteration.id.to_s] },
        weight: 'ANY',
        status: { name: 'To do' }
      }

      expect(IssuableExportCsvWorker)
        .to receive(:perform_async).with(:work_item, current_user.id, project.id, expected_arguments)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['message']).to eq(
        'Your CSV export request has succeeded. The result will be emailed to ' \
          "#{guest.notification_email_or_default}."
      )
      expect(mutation_response['errors']).to be_empty
    end

    context 'when iteration_id and iteration_wildcard_id are both provided' do
      let(:input) do
        {
          'selectedFields' => %w[TITLE],
          'projectPath' => project.full_path,
          'iterationId' => iteration.to_gid,
          'iterationWildcardId' => 'ANY'
        }
      end

      it 'generates mutually exclusive filter error' do
        post_graphql_mutation(mutation, current_user: current_user)
        expect_graphql_errors_to_include(
          'Only one of [iterationId, iterationWildcardId] arguments is allowed at the same time.'
        )
      end
    end

    context 'when weight and weight_wildcard_id are both provided' do
      let(:input) do
        {
          'selectedFields' => %w[TITLE],
          'projectPath' => project.full_path,
          'weight' => '1',
          'weightWildcardId' => 'ANY'
        }
      end

      it 'generates mutually exclusive filter error' do
        post_graphql_mutation(mutation, current_user: current_user)
        expect_graphql_errors_to_include(
          'Only one of [weight, weightWildcardId] arguments is allowed at the same time.'
        )
      end
    end
  end
end
