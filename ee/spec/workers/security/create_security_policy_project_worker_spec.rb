# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CreateSecurityPolicyProjectWorker, "#perform", feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }

    let(:user_id) { user.id }
    let(:container_path) { project.full_path }

    subject(:run_worker) { described_class.new.perform(container_path, user_id) }

    before_all do
      group.add_owner(user)
    end

    shared_examples 'a worker that does not call the ProjectCreateService' do
      it 'does not call the ProjectCreateService' do
        expect(Security::SecurityOrchestrationPolicies::ProjectCreateService).not_to receive(:new)
      end
    end

    it 'calls the ProjectCreateService' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::ProjectCreateService,
        container: project,
        current_user: user
      ) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      run_worker
    end

    it 'triggers the security_policy_project_created GraphQL event' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::ProjectCreateService,
        container: project,
        current_user: user
      ) do |service|
        expect(service).to receive(:execute).and_return({ status: :success, policy_project: 'a policy project' })
      end

      expect(GraphqlTriggers).to receive(:security_policy_project_created).with(
        project, :success, "a policy project", [])

      run_worker
    end

    context 'when ProjectCreateService returns an error' do
      specify do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::ProjectCreateService,
          container: project,
          current_user: user
        ) do |service|
          expect(service).to receive(:execute).and_return(
            { status: :error, message: 'Security Policy project already exists.' }
          )
        end

        expect(GraphqlTriggers).to receive(:security_policy_project_created).with(
          project, :error, nil, ['Security Policy project already exists.']
        )

        run_worker
      end
    end

    context 'when user can\'t be found' do
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'a worker that does not call the ProjectCreateService'

      it 'triggers the subscription with an error' do
        expect(GraphqlTriggers).to receive(:security_policy_project_created).with(
          project, :error, nil, ['User not found.']
        )

        run_worker
      end
    end

    context 'when container can\'t be found' do
      let(:container_path) { non_existing_record_id }

      it_behaves_like 'a worker that does not call the ProjectCreateService'

      it 'triggers the subscription with an error' do
        expect(GraphqlTriggers).to receive(:security_policy_project_created).with(
          nil, :error, nil, ['Group or project not found.']
        )

        run_worker
      end
    end

    context 'when container and user can\'t be found' do
      let(:container_path) { non_existing_record_id }
      let(:user_id) { non_existing_record_id }

      it_behaves_like 'a worker that does not call the ProjectCreateService'

      it 'triggers the subscription with an error' do
        expect(GraphqlTriggers).to receive(:security_policy_project_created).with(
          nil, :error, nil, ['Group or project not found.', 'User not found.']
        )

        run_worker
      end
    end
  end
end
