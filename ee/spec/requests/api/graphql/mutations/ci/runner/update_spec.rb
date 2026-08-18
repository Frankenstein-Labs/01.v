# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::Runner::Update, feature_category: :runner_core do
  include GraphqlHelpers

  let(:runner) do
    create(:ci_runner,
      active: true, locked: false, run_untagged: true,
      public_projects_minutes_cost_factor: 0.0, private_projects_minutes_cost_factor: 0.0)
  end

  let(:mutation) { graphql_mutation(:runner_update, mutation_params) }

  subject(:mutation_result) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:runner_update)
  end

  context 'when user can update runner', :enable_admin_mode do
    let(:current_user) { create(:user, :admin) }

    context 'when create mutation includes cost factor arguments' do
      let(:public_cost_factor) { 2.5 }
      let(:private_cost_factor) { 0.5 }
      let(:mutation_params) do
        {
          id: GitlabSchema.id_from_object(runner).to_s,
          public_projects_minutes_cost_factor: public_cost_factor,
          private_projects_minutes_cost_factor: private_cost_factor
        }
      end

      it 'updates cost factors to specified values', :aggregate_failures do
        expect do
          mutation_result

          runner.reload

          expect_graphql_errors_to_be_empty
          expect(mutation_response).to have_key('runner')
          expect(mutation_response['runner']['publicProjectsMinutesCostFactor']).to eq(public_cost_factor)
          expect(mutation_response['runner']['privateProjectsMinutesCostFactor']).to eq(private_cost_factor)
        end
          .to change { runner.public_projects_minutes_cost_factor }.from(0).to(public_cost_factor)
          .and change { runner.private_projects_minutes_cost_factor }.from(0).to(private_cost_factor)
      end
    end
  end
end
