# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::TrackedContextFinder, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let(:finder) { described_class.new }

  describe '#find_or_create_from_pipeline' do
    subject(:find_or_create) { finder.find_or_create_from_pipeline(pipeline) }

    context 'when pipeline is on the default branch' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }

      context 'when tracked context does not exist' do
        it 'creates a new tracked context' do
          expect { find_or_create }.to change { Security::ProjectTrackedContext.count }.by(1)
        end

        it 'creates a tracked context with correct attributes' do
          result = find_or_create

          expect(result).to have_attributes(
            project_id: project.id,
            context_name: project.default_branch,
            context_type: 'branch',
            state: Security::ProjectTrackedContext::STATES[:tracked],
            is_default: true
          )
        end
      end

      context 'when tracked context already exists' do
        let_it_be(:existing_context) do
          create(:security_project_tracked_context, :tracked,
            project: project,
            context_name: pipeline.ref,
            context_type: :branch)
        end

        it 'does not create a new tracked context' do
          expect { find_or_create }.not_to change { Security::ProjectTrackedContext.count }
        end

        it 'returns the existing tracked context' do
          expect(find_or_create).to eq(existing_context)
        end
      end

      context 'when called multiple times with the same pipeline' do
        it 'uses the cache and does not query the database again' do
          first_result = find_or_create

          expect(Security::ProjectTrackedContexts::FindOrCreateService).not_to receive(:from_pipeline)

          second_result = finder.find_or_create_from_pipeline(pipeline)

          expect(second_result).to eq(first_result)
        end
      end
    end

    context 'when pipeline is not on the default branch' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      context 'when tracked context exists' do
        let_it_be_with_reload(:existing_context) do
          create(:security_project_tracked_context, :tracked,
            project: project,
            context_name: pipeline.ref,
            context_type: :branch)
        end

        it 'returns the existing tracked context' do
          expect(find_or_create).to eq(existing_context)
        end

        it 'does not create a new tracked context' do
          expect { find_or_create }.not_to change { Security::ProjectTrackedContext.count }
        end

        context 'when context is not tracked' do
          before do
            existing_context.untrack!
          end

          it 'raises an ArgumentError' do
            expect { find_or_create }.to raise_error(
              ArgumentError,
              'Context is not tracked'
            )
          end
        end
      end

      context 'when tracked context does not exist' do
        it 'raises an ArgumentError' do
          expect { find_or_create }.to raise_error(
            ArgumentError,
            'Expected context to already exist for non-default branches'
          )
        end
      end
    end

    context 'when pipeline is a tag' do
      let_it_be(:pipeline) { create(:ci_pipeline, :tag, project: project, ref: 'v1.0.0') }

      context 'when tracked context exists' do
        let_it_be(:existing_context) do
          create(:security_project_tracked_context, :tracked, :tag,
            project: project,
            context_name: pipeline.ref)
        end

        it 'returns the existing tracked context' do
          expect(find_or_create).to eq(existing_context)
        end
      end

      context 'when tracked context does not exist' do
        it 'raises an ArgumentError' do
          expect { find_or_create }.to raise_error(
            ArgumentError,
            'Expected context to already exist for non-default branches'
          )
        end
      end
    end

    context 'with multiple pipelines' do
      let_it_be(:pipeline1) { create(:ci_pipeline, project: project, ref: project.default_branch) }
      let_it_be(:pipeline2) { create(:ci_pipeline, project: project, ref: project.default_branch) }

      it 'caches results per pipeline ID' do
        result1 = finder.find_or_create_from_pipeline(pipeline1)
        result2 = finder.find_or_create_from_pipeline(pipeline2)

        expect(result1).to eq(result2)
      end
    end
  end

  describe '#find_or_create_from_project' do
    subject(:find_or_create) { finder.find_or_create_from_project(project) }

    context 'when tracked context does not exist' do
      it 'creates a new tracked context' do
        expect { find_or_create }.to change { Security::ProjectTrackedContext.count }.by(1)
      end

      it 'creates a tracked context with correct attributes' do
        result = find_or_create

        expect(result).to have_attributes(
          project_id: project.id,
          context_name: project.default_branch,
          context_type: 'branch',
          state: Security::ProjectTrackedContext::STATES[:tracked],
          is_default: true
        )
      end
    end

    context 'when tracked context already exists' do
      let_it_be(:existing_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: project.default_branch,
          context_type: :branch)
      end

      it 'does not create a new tracked context' do
        expect { find_or_create }.not_to change { Security::ProjectTrackedContext.count }
      end

      it 'returns the existing tracked context' do
        expect(find_or_create).to eq(existing_context)
      end
    end

    context 'when called multiple times with the same project' do
      it 'uses the cache and does not query the database again' do
        first_result = find_or_create

        expect(Security::ProjectTrackedContexts::FindOrCreateService).not_to receive(:new)

        second_result = finder.find_or_create_from_project(project)

        expect(second_result).to eq(first_result)
      end
    end
  end
end
