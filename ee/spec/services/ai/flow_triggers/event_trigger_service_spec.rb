# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::EventTriggerService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository, :in_group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }

  let(:data) { { user: { id: current_user.id } } }
  let(:event) { :pipeline_hooks }

  subject(:execute) do
    described_class.new(project: project, current_user: current_user, event: event, data: data).execute
  end

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)

    if current_user
      allow(current_user).to receive(:allowed_to_use?)
        .with(:duo_agent_platform, root_namespace: project.root_ancestor).and_return(true)
    end
  end

  describe '#execute' do
    context 'with flow triggers' do
      let_it_be_with_reload(:flow_triggers) do
        Array.new(2) do
          create(:ai_flow_trigger, project: project,
            event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]])
        end
      end

      it 'initializes RunService with expected arguments' do
        run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
        flow_triggers.each do |flow_trigger|
          expect(::Ai::FlowTriggers::RunService).to receive(:new)
            .with(project: project, current_user: current_user, flow_trigger: flow_trigger, resource: nil)
            .and_return(run_service)
        end

        execute
      end

      it 'executes RunService with expected arguments' do
        run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
        allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
        expect(run_service).to receive(:execute).twice.with({ input: data.to_json, event: event })

        execute
      end

      context 'when the current user is not permitted to trigger AI flows' do
        let(:current_user) { create(:user, reporter_of: project) }

        it 'does not initialize RunService' do
          expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

          execute
        end
      end

      context 'when the current user is nil' do
        let(:current_user) { nil }
        let(:data) { {} }

        it 'does not initialize RunService' do
          expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

          execute
        end
      end

      context 'when hook data contains a pipeline id' do
        let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
        let(:data) { { user: { id: current_user.id }, object_attributes: { id: pipeline.id } } }

        it 'passes the pipeline as resource to RunService' do
          run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
          flow_triggers.each do |flow_trigger|
            expect(::Ai::FlowTriggers::RunService).to receive(:new)
              .with(project: project, current_user: current_user, flow_trigger: flow_trigger, resource: pipeline)
              .and_return(run_service)
          end

          execute
        end

        context 'when the event is not pipeline_hooks' do
          let_it_be(:flow_triggers) do
            Array.new(2) do
              create(:ai_flow_trigger, project: project, event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]])
            end
          end

          let(:event) { :mention }

          it 'passes nil as resource' do
            run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
            flow_triggers.each do |flow_trigger|
              expect(::Ai::FlowTriggers::RunService).to receive(:new)
                .with(project: project, current_user: current_user, flow_trigger: flow_trigger, resource: nil)
                .and_return(run_service)
            end

            execute
          end
        end
      end

      it 'skips triggers when the filter evaluates to false' do
        flow_triggers.each do |flow_trigger|
          flow_trigger.update!(filter: {
            event.to_s => {
              'rules' => [
                { 'field' => 'object_attributes.status', 'operator' => 'eq', 'value' => 'failed' }
              ],
              'match' => 'all'
            }
          })
        end

        run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
        allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
        allow(::Gitlab::FilterEvaluator).to receive(:evaluate).and_return(false)
        expect(run_service).not_to receive(:execute)

        execute
      end

      it 'runs triggers when the filter evaluates to true' do
        data[:object_attributes] = { status: 'failed' }

        flow_triggers.each do |flow_trigger|
          flow_trigger.update!(filter: {
            event.to_s => {
              'rules' => [
                { 'field' => 'object_attributes.status', 'operator' => 'eq', 'value' => 'failed' }
              ],
              'match' => 'all'
            }
          })
        end

        run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
        allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
        allow(::Gitlab::FilterEvaluator).to receive(:evaluate).and_return(true)
        expect(run_service).to receive(:execute).twice.with({ input: data.to_json, event: event })

        execute
      end

      context 'when a flow trigger has a foundational flow precondition' do
        let_it_be(:failed_pipeline) { create(:ci_pipeline, :failed, project: project) }
        let_it_be(:item) { create(:ai_catalog_flow, :public, foundational_flow_reference: 'fix_pipeline/v1') }
        let_it_be(:item_consumer) do
          create(:ai_catalog_item_consumer, :child_item_consumer, project: project, item: item)
        end

        let_it_be(:precondition_trigger) do
          create(:ai_flow_trigger,
            :for_catalog_consumer,
            project: project,
            ai_catalog_item_consumer: item_consumer,
            event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]])
        end

        it 'skips triggers when the precondition is not met' do
          data[:object_attributes] = { id: failed_pipeline.id }

          run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
          allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

          execute

          expect(::Ai::FlowTriggers::RunService).not_to have_received(:new)
            .with(hash_including(flow_trigger: precondition_trigger))
        end

        it 'runs triggers when the precondition is met' do
          data[:object_attributes] = { id: failed_pipeline.id, status: 'failed' }

          run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
          allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

          execute

          expect(::Ai::FlowTriggers::RunService).to have_received(:new)
            .with(hash_including(flow_trigger: precondition_trigger))
        end

        context 'when the pipeline is in an intermediate state due to job retries' do
          let_it_be(:running_pipeline) { create(:ci_pipeline, :running, project: project) }

          it 'skips fix_pipeline/v1 flow triggers' do
            data[:object_attributes] = { id: running_pipeline.id, status: 'failed' }

            run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
            allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

            execute

            expect(::Ai::FlowTriggers::RunService).not_to have_received(:new)
              .with(hash_including(flow_trigger: precondition_trigger))
          end
        end

        context 'when the pipeline may be stale' do
          let(:data) do
            { user: { id: current_user.id }, object_attributes: { id: pipeline.id, status: 'failed' } }
          end

          shared_examples 'triggering the fix_pipeline flow' do
            it 'runs fix_pipeline/v1 flow triggers' do
              run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
              allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

              execute

              expect(::Ai::FlowTriggers::RunService).to have_received(:new)
                .with(hash_including(flow_trigger: precondition_trigger))
            end
          end

          shared_examples 'skipping the fix_pipeline flow' do
            it 'skips fix_pipeline/v1 flow triggers' do
              run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
              allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

              execute

              expect(::Ai::FlowTriggers::RunService).not_to have_received(:new)
                .with(hash_including(flow_trigger: precondition_trigger))
            end
          end

          context 'when the pipeline is associated with a merge request' do
            let_it_be(:merge_request) { create(:merge_request, source_project: project) }
            let(:ref) { merge_request.source_branch }
            let(:head_sha) { merge_request.diff_head_sha }
            let(:other_sha) { 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }

            context 'when the pipeline is a detached merge request pipeline' do
              context 'and it ran against the current source branch head' do
                let(:pipeline) do
                  create(:ci_pipeline, :failed, project: project, merge_request: merge_request, ref: ref, sha: head_sha)
                end

                it_behaves_like 'triggering the fix_pipeline flow'
              end

              context 'and a newer commit exists on the source branch' do
                let(:pipeline) do
                  create(:ci_pipeline, :failed, project: project, merge_request: merge_request,
                    ref: ref, sha: other_sha)
                end

                it_behaves_like 'skipping the fix_pipeline flow'
              end
            end

            context 'when the pipeline is a merged results pipeline' do
              # For merged results pipelines the source branch head is carried in source_sha.
              context 'and it ran against the current source branch head' do
                let(:pipeline) do
                  create(:ci_pipeline, :failed, project: project, merge_request: merge_request,
                    ref: ref, sha: other_sha, source_sha: head_sha, target_sha: other_sha)
                end

                it_behaves_like 'triggering the fix_pipeline flow'
              end

              context 'and a newer commit exists on the source branch' do
                let(:pipeline) do
                  create(:ci_pipeline, :failed, project: project, merge_request: merge_request,
                    ref: ref, sha: other_sha, source_sha: other_sha, target_sha: other_sha)
                end

                it_behaves_like 'skipping the fix_pipeline flow'
              end
            end
          end

          context 'when the pipeline is not associated with a merge request' do
            let(:pipeline) { create(:ci_pipeline, :failed, project: project) }

            it_behaves_like 'triggering the fix_pipeline flow'
          end
        end

        context 'when fix_pipeline_gradual_trigger_group is disabled for the group' do
          before do
            stub_feature_flags(fix_pipeline_gradual_trigger_group: false)
          end

          it 'runs fix_pipeline/v1 flow triggers without gradual rollout' do
            data[:object_attributes] = { id: failed_pipeline.id, status: 'failed' }

            run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
            allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

            execute

            expect(::Ai::FlowTriggers::RunService).to have_received(:new)
              .with(hash_including(flow_trigger: precondition_trigger))
          end
        end

        context 'when fix_pipeline_gradual_trigger_group is enabled for the group' do
          before do
            stub_feature_flags(fix_pipeline_gradual_trigger_group: project.root_group)
          end

          context 'when fix_pipeline_gradual_trigger_gate is disabled' do
            before do
              stub_feature_flags(fix_pipeline_gradual_trigger_gate: false)
            end

            it 'skips fix_pipeline/v1 flow triggers' do
              data[:object_attributes] = { id: failed_pipeline.id, status: 'failed' }

              run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
              allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

              execute

              expect(::Ai::FlowTriggers::RunService).not_to have_received(:new)
                .with(hash_including(flow_trigger: precondition_trigger))
            end
          end

          context 'when fix_pipeline_gradual_trigger_gate is enabled' do
            before do
              stub_feature_flags(fix_pipeline_gradual_trigger_gate: true)
            end

            it 'runs fix_pipeline/v1 flow triggers' do
              data[:object_attributes] = { id: failed_pipeline.id, status: 'failed' }

              run_service = instance_double(::Ai::FlowTriggers::RunService, execute: nil)
              allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)

              execute

              expect(::Ai::FlowTriggers::RunService).to have_received(:new)
                .with(hash_including(flow_trigger: precondition_trigger))
            end
          end
        end
      end
    end

    context 'with no matching flow trigger' do
      let_it_be(:flow_trigger) do
        create(:ai_flow_trigger, project: project, event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]])
      end

      it 'does not initialize RunService' do
        expect(::Ai::FlowTriggers::RunService).not_to receive(:new)

        execute
      end
    end
  end
end
