# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'exporting detailed membership data', feature_category: :system_access do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:input) { { 'group_id' => group.to_global_id.to_s } }
  let(:mutation) { graphql_mutation(:groupMembersExport, input, fields) }
  let(:fields) do
    <<~FIELDS
      errors
      message
    FIELDS
  end

  subject(:export_members) { graphql_mutation_response(:group_members_export) }

  before do
    stub_licensed_features(export_user_permissions: true)
  end

  context 'when members_permissions_detailed_export` FF is disabled' do
    before do
      stub_feature_flags(members_permissions_detailed_export: false)
    end

    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when members_permissions_detailed_export` FF is enabled' do
    before do
      stub_feature_flags(members_permissions_detailed_export: true)
    end

    context 'with maintainer role' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'with owner role' do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_member do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:mutation) { graphql_mutation(:groupMembersExport, input, 'errors') }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'returns success' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to be_nil

        expect(export_members['message']).to include('Your CSV export request has succeeded.')
      end

      it 'calls the ExportRunner' do
        export_runner = instance_double(Namespaces::Export::ExportRunner)

        expect(Namespaces::Export::ExportRunner).to receive(:new).with(group, current_user)
          .and_return(export_runner)
        expect(export_runner).to receive(:execute)

        post_graphql_mutation(mutation, current_user: current_user)
      end
    end
  end
end
