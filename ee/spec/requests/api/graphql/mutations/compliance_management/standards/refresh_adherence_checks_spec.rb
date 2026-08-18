# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Refresh adherence checks', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, name: 'sub-group', parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:sub_group_project) { create(:project, namespace: sub_group) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) { graphql_mutation(:refresh_standards_adherence_checks, input) }
  let(:mutation_response) { graphql_mutation_response(:refresh_standards_adherence_checks) }

  let(:input) { { groupPath: group.full_path } }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'a mutation that does not invoke RefreshService' do
    it 'does not update the standards adherence checks' do
      expect { mutate }
        .not_to change { Projects::ComplianceStandards::Adherence.count }
    end
  end

  shared_examples 'an unauthorized mutation that does not create a configuration' do
    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not invoke RefreshService'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(group_level_compliance_dashboard: true, group_level_compliance_adherence_report: true)
    end

    context 'when current user is a group owner', :freeze_time, :sidekiq_inline do
      before_all do
        group.add_owner(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :read_compliance_dashboard do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:mutation) { graphql_mutation(:refresh_standards_adherence_checks, input, 'errors') }

        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      it 'creates or updates the standards adherence checks for all the projects inside group', :aggregate_failures do
        expect(project.compliance_standards_adherence.count).to eq(0)
        expect(sub_group_project.compliance_standards_adherence.count).to eq(0)

        expect_next_instance_of(ComplianceManagement::Standards::RefreshService,
          { group: group, current_user: current_user }) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        mutate

        expect(project.compliance_standards_adherence.count).to eq(6)
        expect(sub_group_project.compliance_standards_adherence.count).to eq(6)
        expect(mutation_response['adherenceChecksStatus']['startedAt']).to eq(Time.now.utc.iso8601)
        expect(mutation_response['adherenceChecksStatus']['checksCompleted']).to eq(12)
        expect(mutation_response['adherenceChecksStatus']['totalChecks']).to eq(12)
      end

      context 'when refresh service errors', :freeze_time, :sidekiq_inline do
        before_all do
          group.add_owner(current_user)
        end

        it 'returns the error response' do
          expect_next_instance_of(ComplianceManagement::Standards::RefreshService,
            { group: group, current_user: current_user }) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.error(message: 'something went wrong!'))
          end

          mutate

          expect(project.compliance_standards_adherence.count).to eq(0)
          expect(sub_group_project.compliance_standards_adherence.count).to eq(0)
          expect(mutation_response['adherenceChecksStatus']).to be_nil
          expect(mutation_response['errors']).to eq(['something went wrong!'])
        end
      end
    end

    context 'when current user does not have required access' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'an unauthorized mutation that does not create a configuration'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(group_level_compliance_dashboard: false)
    end

    it_behaves_like 'an unauthorized mutation that does not create a configuration'
  end
end
