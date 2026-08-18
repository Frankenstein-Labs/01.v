# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::CreateOrUpdateDefaultTrackedContextWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let(:worker) { described_class.new }

  describe '#handle_event' do
    subject(:handle_event) { worker.handle_event(event) }

    shared_examples 'creates or updates default tracked context' do
      context 'when project exists' do
        it 'creates a default tracked context for the project default branch' do
          expect { handle_event }.to change { Security::ProjectTrackedContext.count }.by(1)

          tracked_context = Security::ProjectTrackedContext.last
          expect(tracked_context.project).to eq(project)
          expect(tracked_context.context_name).to eq(project.default_branch_or_main)
          expect(tracked_context.context_type).to eq('branch')
          expect(tracked_context.is_default).to be true
          expect(tracked_context).to be_tracked
        end

        it 'calls the FindOrCreateService with correct parameters' do
          expect(Security::ProjectTrackedContexts::FindOrCreateService)
            .to receive(:project_default_branch)
            .with(project)
            .and_call_original

          handle_event
        end

        context 'when FindOrCreateService returns success' do
          it 'does not log any warnings' do
            expect(Gitlab::AppLogger).not_to receive(:warn)

            handle_event
          end
        end

        context 'when FindOrCreateService returns error' do
          let(:error_messages) { ['Some error', 'Another error'] }
          let(:service_result) do
            ServiceResponse.error(
              message: error_messages,
              payload: {
                tracked_context: build(:security_project_tracked_context)
              }
            )
          end

          before do
            allow(Security::ProjectTrackedContexts::FindOrCreateService)
              .to receive(:project_default_branch)
              .with(project)
              .and_return(instance_double(
                Security::ProjectTrackedContexts::FindOrCreateService,
                execute: service_result
              ))
          end

          it 'logs a warning with error details' do
            expect(Gitlab::AppLogger).to receive(:warn).with(
              message: "Failed to create default tracked context for project: Some error,Another error",
              project_id: project.id,
              project_path: project.full_path
            )

            handle_event
          end
        end

        it 'does not create duplicate default tracked contexts if run twice' do
          2.times { handle_event }
          expect(Security::ProjectTrackedContext.count).to eq(1)
        end
      end

      context 'when project does not exist' do
        let(:project_id) { non_existing_record_id }

        it 'does not create any tracked context' do
          expect { handle_event }.not_to change { Security::ProjectTrackedContext.count }
        end

        it 'does not raise an error' do
          expect { handle_event }.not_to raise_error
        end

        it 'does not call FindOrCreateService' do
          expect(Security::ProjectTrackedContexts::FindOrCreateService).not_to receive(:project_default_branch)

          handle_event
        end
      end

      include_examples 'an idempotent worker' do
        let(:job_args) { [event] }
      end
    end

    context 'when handling ProjectCreatedEvent' do
      let(:project_id) { project.id }
      let(:event) do
        Projects::ProjectCreatedEvent.new(data: {
          project_id: project_id,
          namespace_id: project.namespace_id,
          root_namespace_id: project.root_namespace.id
        })
      end

      it_behaves_like 'creates or updates default tracked context'
    end

    context 'when handling DefaultBranchChangedEvent' do
      let(:project_id) { project.id }
      let(:event) do
        Repositories::DefaultBranchChangedEvent.new(data: {
          container_id: project_id,
          container_type: 'Project'
        })
      end

      it_behaves_like 'creates or updates default tracked context'
    end

    context 'when handling RepositoryCreatedEvent' do
      let(:project_id) { project.id }
      let(:event) do
        Repositories::RepositoryCreatedEvent.new(data: {
          container_id: project_id,
          container_type: 'Project'
        })
      end

      it_behaves_like 'creates or updates default tracked context'
    end

    context 'when handling other events' do
      let(:project_id) { project.id }
      let(:event) do
        Projects::ProjectDeletedEvent.new(data: {
          project_id: project_id,
          namespace_id: project.namespace_id,
          root_namespace_id: project.root_namespace.id
        })
      end

      it 'does not do anything' do
        expect { handle_event }.not_to change { Security::ProjectTrackedContext.count }
      end
    end
  end

  describe '.idempotency_arguments' do
    it 'returns project_id for ProjectCreatedEvent' do
      event = Projects::ProjectCreatedEvent.new(data: { project_id: 123, namespace_id: 123, root_namespace_id: 123 })
      expect(described_class.idempotency_arguments([event.class.name, event.data])).to eq([123])
    end

    it 'returns container_id for DefaultBranchChangedEvent' do
      event = Repositories::DefaultBranchChangedEvent.new(data: { container_id: 456, container_type: 'Project' })
      expect(described_class.idempotency_arguments([event.class.name, event.data])).to eq([456])
    end

    it 'returns container_id for RepositoryCreatedEvent' do
      event = Repositories::RepositoryCreatedEvent.new(data: { container_id: 789, container_type: 'Project' })
      expect(described_class.idempotency_arguments([event.class.name, event.data])).to eq([789])
    end

    it 'returns nil for unknown event' do
      event = Projects::ProjectDeletedEvent.new(data: { project_id: 123, namespace_id: 123, root_namespace_id: 123 })
      expect(described_class.idempotency_arguments([event.class.name, event.data])).to eq([nil])
    end
  end

  it 'has until_executed deduplication strategy and if_deduplicated: :reschedule_once as options' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    expect(described_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once })
  end

  it 'prepends Geo::SkipSecondary to skip execution on Geo secondary sites' do
    expect(described_class.ancestors).to include(::Geo::SkipSecondary)
  end

  context 'when running on a Geo secondary site' do
    before do
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
    end

    it 'does not perform any work' do
      event = Repositories::DefaultBranchChangedEvent.new(data: {
        container_id: project.id,
        container_type: 'Project'
      })

      expect(Security::ProjectTrackedContexts::FindOrCreateService).not_to receive(:project_default_branch)
      expect { worker.perform(event.class.name, event.data) }.not_to change { Security::ProjectTrackedContext.count }
    end
  end
end
