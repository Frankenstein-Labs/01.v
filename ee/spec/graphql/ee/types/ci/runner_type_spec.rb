# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiRunner'], feature_category: :runner_core do
  it { expect(described_class.graphql_name).to eq('CiRunner') }

  it 'includes the ee specific fields' do
    expected_fields = %w[
      public_projects_minutes_cost_factor
      private_projects_minutes_cost_factor
      token_rotation_deadline
      upgrade_status
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'URLs to each runners\' page in the admin area' do
    let_it_be(:runner) { create(:ci_runner, :instance) }

    let(:query) do
      %(
          query{
            runners {
              nodes {
                adminUrl
                editAdminUrl
              }
            }
          }
        )
    end

    subject(:response) { GitlabSchema.execute(query, context: { current_user: current_user }) }

    context 'when current user is not an admin with read_admin_cicd custom ability', :enable_admin_mode do
      let_it_be(:current_user) { create(:user) }

      before do
        create(:admin_member_role, :read_admin_cicd, user: current_user)

        stub_licensed_features(custom_roles: true)
      end

      it 'only includes URLs for reading runners' do
        runner = response.dig('data', 'runners', 'nodes', 0)

        expect(runner['adminUrl']).not_to be_nil
        expect(runner['editAdminUrl']).to be_nil
      end
    end
  end
end
