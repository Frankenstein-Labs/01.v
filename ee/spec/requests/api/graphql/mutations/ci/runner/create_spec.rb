# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::Runner::Create, feature_category: :runner_core do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }

  let(:mutation) { graphql_mutation(:runner_create, mutation_params) }

  subject(:mutation_result) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:runner_create)
  end

  context 'when user can create runner', :enable_admin_mode do
    let(:current_user) { create(:user, :admin) }

    context 'when create mutation includes cost factor arguments' do
      let(:public_cost_factor) { 2.5 }
      let(:private_cost_factor) { 0.5 }
      let(:mutation_params) do
        {
          runner_type: 'INSTANCE_TYPE',
          public_projects_minutes_cost_factor: public_cost_factor,
          private_projects_minutes_cost_factor: private_cost_factor
        }
      end

      it 'sets cost factors to specified values', :aggregate_failures do
        expect_next_instance_of(::Ci::Runners::CreateRunnerService) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        mutation_result

        expect_graphql_errors_to_be_empty
        expect(mutation_response).to have_key('runner')
        expect(mutation_response['runner']['publicProjectsMinutesCostFactor']).to eq(public_cost_factor)
        expect(mutation_response['runner']['privateProjectsMinutesCostFactor']).to eq(private_cost_factor)

        runner = GitlabSchema.object_from_id(mutation_response['runner']['id'], expected_type: ::Ci::Runner).sync
        expect(runner.public_projects_minutes_cost_factor).to eq(public_cost_factor)
        expect(runner.private_projects_minutes_cost_factor).to eq(private_cost_factor)
      end
    end

    context 'when token expiration parameters are provided', :freeze_time do
      let(:mutation) do
        graphql_mutation(
          :runner_create,
          mutation_params,
          <<-QL
            runner {
              id
              tokenExpiresAt
              tokenRotationDeadline
            }
            errors
          QL
        )
      end

      context 'when token_expires_at is valid' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 10.days.from_now.iso8601
          }
        end

        it 'creates a runner with token_expires_at set', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to eq([])
          expect(mutation_response['runner']['tokenExpiresAt']).to eq(10.days.from_now.iso8601)

          runner = GitlabSchema.object_from_id(mutation_response['runner']['id'], expected_type: ::Ci::Runner).sync
          expect(runner.token_expires_at).to eq(10.days.from_now)
        end
      end

      context 'when token_expires_at is less than 5 minutes in the future' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 2.minutes.from_now.iso8601
          }
        end

        it 'returns an error', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to include(a_string_including('token_expires_at must be at least'))
        end
      end

      context 'when token_expires_at is more than 15 days in the future' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 20.days.from_now.iso8601
          }
        end

        it 'returns an error', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to include(
            a_string_including('token_expires_at is too far in the future')
          )
        end
      end

      context 'when token_rotation_deadline is provided' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 10.days.from_now.iso8601,
            token_rotation_deadline: 5.days.from_now.iso8601
          }
        end

        it 'creates a runner with token_rotation_deadline set', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to eq([])
          expect(mutation_response['runner']['tokenExpiresAt']).to eq(10.days.from_now.iso8601)
          expect(mutation_response['runner']['tokenRotationDeadline']).to eq(5.days.from_now.iso8601)

          runner = GitlabSchema.object_from_id(mutation_response['runner']['id'], expected_type: ::Ci::Runner).sync
          expect(runner.token_expires_at).to eq(10.days.from_now)
          expect(runner.token_rotation_deadline).to eq(5.days.from_now)
        end
      end

      context 'when token_rotation_deadline is after token_expires_at' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 10.days.from_now.iso8601,
            token_rotation_deadline: 12.days.from_now.iso8601
          }
        end

        it 'returns an error', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to include(
            a_string_including('token_rotation_deadline must be less than or equal to token_expires_at')
          )
        end
      end

      context 'when token_rotation_deadline is in the past' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 10.days.from_now.iso8601,
            token_rotation_deadline: 1.day.ago.iso8601
          }
        end

        it 'returns an error', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to include(
            a_string_including('token_rotation_deadline cannot be in the past')
          )
        end
      end

      context 'when token_rotation_deadline is provided without token_expires_at' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_rotation_deadline: 5.days.from_now.iso8601
          }
        end

        it 'returns an error', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to include(
            a_string_including('token_expires_at is required when token_rotation_deadline is specified')
          )
        end
      end

      context 'when token_rotation_deadline equals token_expires_at' do
        let(:mutation_params) do
          {
            runner_type: 'INSTANCE_TYPE',
            token_expires_at: 10.days.from_now.iso8601,
            token_rotation_deadline: 10.days.from_now.iso8601
          }
        end

        it 'creates a runner with rotation disabled', :aggregate_failures do
          mutation_result

          expect_graphql_errors_to_be_empty
          expect(mutation_response['errors']).to eq([])
          expect(mutation_response['runner']['tokenRotationDeadline']).to eq(10.days.from_now.iso8601)

          runner = GitlabSchema.object_from_id(mutation_response['runner']['id'], expected_type: ::Ci::Runner).sync
          expect(runner.token_rotation_deadline).to eq(10.days.from_now)
        end
      end
    end
  end
end
