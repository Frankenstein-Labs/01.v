# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateAgentPrivilegesService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) do
      described_class.new(
        workflow: workflow,
        agent_privileges: agent_privileges,
        pre_approved_agent_privileges: pre_approved_agent_privileges,
        current_user: user
      ).execute
    end

    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }

    # Web surfaces keep the trusted (unclamped) behavior; local surfaces are
    # clamped to governance and covered in a dedicated context below.
    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user, environment: :web) }
    let(:agent_privileges) { nil }
    let(:pre_approved_agent_privileges) { nil }

    context 'when user does not have permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(false)
      end

      it 'returns unauthorized error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Can not update workflow')
        expect(result.reason).to eq(:unauthorized)
      end
    end

    context 'when user has permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
      end

      context 'when agent_privileges is provided' do
        let(:agent_privileges) { [1, 2] }

        it 'updates agent_privileges and returns success', :aggregate_failures do
          expect(result.success?).to be true
          expect(result.message).to eq('Agent privileges updated successfully')
          expect(result.payload[:workflow]).to eq(workflow)
          expect(workflow.reload.agent_privileges).to eq(agent_privileges)
        end
      end

      context 'when pre_approved_agent_privileges is provided' do
        let(:agent_privileges) { [1, 2] }
        let(:pre_approved_agent_privileges) { [1] }

        it 'updates pre_approved_agent_privileges and returns success', :aggregate_failures do
          expect(result.success?).to be true
          expect(result.message).to eq('Agent privileges updated successfully')
          expect(workflow.reload.pre_approved_agent_privileges).to eq(pre_approved_agent_privileges)
        end
      end

      context 'when neither agent_privileges nor pre_approved_agent_privileges is provided' do
        it 'saves the workflow without changes and returns success', :aggregate_failures do
          expect(result.success?).to be true
          expect(result.message).to eq('Agent privileges updated successfully')
        end
      end

      context 'when agent_privileges contains an invalid value' do
        let(:agent_privileges) { [999] }

        it 'returns an error with validation messages', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to include('Failed to update agent privileges')
          expect(result.message).to include('contains an invalid value 999')
        end
      end

      context 'when pre_approved_agent_privileges contains an invalid value' do
        let(:pre_approved_agent_privileges) { [999] }

        it 'returns an error with validation messages', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to include('Failed to update agent privileges')
          expect(result.message).to include('contains an invalid value 999')
        end
      end

      context 'when the workflow runs on a local surface' do
        let(:workflow) { create(:duo_workflows_workflow, project: project, user: user, environment: :ide) }
        let(:agent_privileges) { [1, 2, 4] }

        before do
          allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ServiceResponse.success(payload: {
                agent_privileges: [1, 2, 7],
                pre_approved_agent_privileges: [2, 7],
                pre_approved_tools: ['read_file']
              })
            )
          end
        end

        it 'clamps the requested privileges to the governance resolution', :aggregate_failures do
          expect(result.success?).to be true
          expect(workflow.reload.agent_privileges).to match_array([1, 2])
        end

        %i[ide chat chat_partial].each do |environment|
          context "when the environment is #{environment}" do
            let(:workflow) do
              create(:duo_workflows_workflow, project: project, user: user, environment: environment)
            end

            it 'resolves governance rules for the local surface' do
              expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
                namespace: project.root_ancestor, surface: environment, project: project
              ).and_call_original

              result
            end
          end
        end

        context 'when the environment is not a recognized local surface' do
          let(:workflow) { create(:duo_workflows_workflow, project: project, user: user, environment: :external) }

          it 'clamps against the web surface rules' do
            expect(Ai::ToolRules::ResolutionService).to receive(:new).with(
              namespace: project.root_ancestor, surface: :web, project: project
            ).and_call_original

            result
          end
        end

        context 'when pre_approved_agent_privileges are also requested' do
          let(:pre_approved_agent_privileges) { [1, 2] }

          it 'clamps them to the resolved pre-approved privileges', :aggregate_failures do
            expect(result.success?).to be true
            expect(workflow.reload.pre_approved_agent_privileges).to match_array([2])
          end
        end

        context 'when the clamped pre-approved privileges are not a subset of the clamped grants' do
          let(:agent_privileges) { [1, 2] }
          let(:pre_approved_agent_privileges) { [1, 2, 7] }

          it 'constrains the pre-approved privileges to the persisted grants', :aggregate_failures do
            expect(result.success?).to be true
            expect(workflow.reload.agent_privileges).to match_array([1, 2])
            expect(workflow.reload.pre_approved_agent_privileges).to match_array([2])
          end
        end

        context 'when governance resolution fails transiently' do
          before do
            allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
              allow(instance).to receive(:execute).and_return(
                ServiceResponse.error(message: 'something went wrong'),
                ServiceResponse.success(payload: {
                  agent_privileges: [1, 2, 7],
                  pre_approved_agent_privileges: [2, 7],
                  pre_approved_tools: ['read_file']
                })
              )
            end
          end

          it 'retries the resolution and clamps the requested privileges', :aggregate_failures do
            expect(result.success?).to be true
            expect(workflow.reload.agent_privileges).to match_array([1, 2])
          end
        end

        context 'when governance resolution keeps failing' do
          before do
            allow_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
              allow(instance).to receive(:execute).and_return(
                ServiceResponse.error(message: 'something went wrong')
              )
            end
          end

          it 'returns an error without persisting any privilege change', :aggregate_failures do
            original_privileges = workflow.agent_privileges
            original_pre_approved = workflow.pre_approved_agent_privileges

            expect(result.error?).to be true
            expect(result.reason).to eq(:governance_resolution_failed)
            expect(workflow.reload.agent_privileges).to eq(original_privileges)
            expect(workflow.reload.pre_approved_agent_privileges).to eq(original_pre_approved)
          end

          it 'retries the resolution service up to MAX_GOVERNANCE_RETRIES times' do
            expect_next_instance_of(Ai::ToolRules::ResolutionService) do |instance|
              expect(instance).to receive(:execute)
                .exactly(described_class::MAX_GOVERNANCE_RETRIES).times
                .and_return(ServiceResponse.error(message: 'something went wrong'))
            end

            result
          end

          context 'when only pre_approved_agent_privileges are requested' do
            let(:agent_privileges) { nil }
            let(:pre_approved_agent_privileges) { [1] }

            it 'returns an error and leaves agent_privileges untouched', :aggregate_failures do
              original_privileges = workflow.agent_privileges

              expect(result.error?).to be true
              expect(workflow.reload.agent_privileges).to eq(original_privileges)
            end
          end
        end

        context 'when gitlab_duo_governance_settings flag is disabled' do
          before do
            stub_feature_flags(gitlab_duo_governance_settings: false)
          end

          it 'keeps the requested privileges', :aggregate_failures do
            expect(Ai::ToolRules::ResolutionService).not_to receive(:new)

            expect(result.success?).to be true
            expect(workflow.reload.agent_privileges).to match_array([1, 2, 4])
          end
        end

        context 'when the duo_workflow_local_tool_governance flag is disabled' do
          before do
            stub_feature_flags(duo_workflow_local_tool_governance: false)
          end

          it 'keeps the requested privileges', :aggregate_failures do
            expect(Ai::ToolRules::ResolutionService).not_to receive(:new)

            expect(result.success?).to be true
            expect(workflow.reload.agent_privileges).to match_array([1, 2, 4])
          end
        end
      end
    end
  end
end
