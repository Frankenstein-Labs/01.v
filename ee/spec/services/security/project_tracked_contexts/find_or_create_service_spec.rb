# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::FindOrCreateService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  let_it_be(:guest_user) { create(:user) }

  let(:context_name) { project.default_branch }
  let(:context_type) { :branch }
  let(:is_default) { true }
  let(:allow_untracked) { false }

  let(:params) do
    {
      project: project,
      context_name: context_name,
      context_type: context_type,
      is_default: is_default,
      allow_untracked: allow_untracked
    }
  end

  subject(:service) { described_class.new(**params) }

  before_all do
    project.add_maintainer(user)
    project.add_guest(guest_user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    allow(project).to receive(:repository_exists?).and_return(true)
    allow(project.repository).to receive_messages(branch_exists?: true, tag_exists?: true)
  end

  RSpec.shared_examples 'context creation' do
    it 'creates a new tracked context' do
      expect { service.execute }.to change { Security::ProjectTrackedContext.count }.by(1)
    end

    it 'returns success with the created context' do
      expected_state = if allow_untracked
                         Security::ProjectTrackedContext::STATES[:untracked]
                       else
                         Security::ProjectTrackedContext::STATES[:tracked]
                       end

      expect(result).to be_success
      tracked_context = result.payload[:tracked_context]
      expect(tracked_context).to be_persisted
      expect(tracked_context.project).to eq(project)
      expect(tracked_context.context_name).to eq(context_name)
      expect(tracked_context.context_type).to eq(context_type.to_s)
      expect(tracked_context.state).to eq(expected_state)
      expect(tracked_context.is_default).to be(is_default)
      expect(tracked_context.traversal_ids).to eq(project.namespace.traversal_ids)
      expect(tracked_context.uuid_version).to eq(Security::ProjectTrackedContext::CONTEXT_AWARE_UUID_VERSION)
    end

    it 'logs the creation of the tracked context' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          'class_name' => described_class.name,
          'message' => 'Security tracked context created',
          'gl_project_id' => project.id,
          'context_name' => context_name,
          'context_type' => context_type.to_s,
          'is_default' => is_default
        )
      )

      service.execute
    end

    context 'when creation fails due to validation errors' do
      let(:context_name) { nil }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Invalid ref name or type specified')
      end

      it 'does not create a tracked context' do
        expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
      end
    end
  end

  RSpec.shared_examples 'existing tracked context' do
    it 'returns success with the existing context' do
      expect(result).to be_success
      expect(result.payload[:tracked_context]).to eq(existing_context)
    end

    it 'does not create a new tracked context' do
      expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
    end

    it 'does not update the existing context' do
      expect { service.execute }.not_to change { existing_context.reload.state }
    end
  end

  describe '.from_pipeline' do
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

    subject(:service) { described_class.from_pipeline(pipeline) }

    context 'when pipeline is for a branch' do
      it 'initializes service with correct branch parameters' do
        expect(service.project).to eq(project)
        expect(service.context_name).to eq('feature-branch')
        expect(service.context_type).to eq(:branch)
        expect(service.is_default).to be false
      end
    end

    context 'when pipeline is for a tag' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'v1.0.0', tag: true) }

      it 'initializes service with correct tag parameters' do
        expect(service.project).to eq(project)
        expect(service.context_name).to eq('v1.0.0')
        expect(service.context_type).to eq(:tag)
        expect(service.is_default).to be false
      end
    end

    context 'when pipeline is for the default branch' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }

      it 'sets is_default to true' do
        expect(service.is_default).to be true
      end
    end
  end

  describe '.project_default_branch' do
    subject(:service) { described_class.project_default_branch(project) }

    it 'initializes service for the default branch' do
      expect(service.project).to eq(project)
      expect(service.context_name).to eq(project.default_branch)
      expect(service.context_type).to eq(:branch)
      expect(service.is_default).to be(true)
    end
  end

  describe '#execute' do
    subject(:result) { service.execute }

    context 'when current_user is present (GraphQL API usage)' do
      let(:params) do
        {
          project: project,
          context_name: 'feature-branch',
          context_type: :branch,
          is_default: false,
          allow_untracked: false,
          current_user: user
        }
      end

      before do
        allow(project.repository).to receive(:branch_exists?).with('feature-branch').and_return(true)
      end

      context 'when user has permission' do
        it 'allows the operation' do
          expect(result).to be_error
          expect(result.message).to eq('Expected context to already exist for non-default branches')
        end
      end

      context 'when user lacks permission' do
        let(:params) do
          {
            project: project,
            context_name: 'feature-branch',
            context_type: :branch,
            is_default: false,
            allow_untracked: false,
            current_user: guest_user
          }
        end

        it 'returns permission error' do
          expect(result).to be_error
          expect(result.message).to eq('Permission denied')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'when ref validation fails' do
        before do
          allow(project.repository).to receive(:branch_exists?).with('feature-branch').and_return(false)
        end

        it 'returns ref not found error' do
          expect(result).to be_error
          expect(result.message).to eq('Ref does not exist in repository')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'when repository does not exist' do
        before do
          allow(project).to receive(:repository_exists?).and_return(false)
        end

        it 'returns ref not found error' do
          expect(result).to be_error
          expect(result.message).to eq('Ref does not exist in repository')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'when parameters are invalid' do
        let(:params) do
          {
            project: project,
            context_name: '',
            context_type: 'invalid',
            is_default: false,
            allow_untracked: false,
            current_user: user
          }
        end

        it 'returns validation error' do
          expect(result).to be_error
          expect(result.message).to eq('Invalid ref name or type specified')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'when ref_type is tag' do
        let(:params) do
          {
            project: project,
            context_name: 'v1.0.0',
            context_type: :tag,
            is_default: false,
            allow_untracked: false,
            current_user: user
          }
        end

        before do
          allow(project.repository).to receive(:tag_exists?).with('v1.0.0').and_return(true)
          allow(project.repository).to receive(:branch_exists?).with('v1.0.0').and_return(false)
        end

        it 'validates tag existence' do
          expect(result).to be_error
          expect(result.message).to eq('Expected context to already exist for non-default branches')
        end

        context 'when tag does not exist' do
          before do
            allow(project.repository).to receive(:tag_exists?).with('v1.0.0').and_return(false)
          end

          it 'returns ref not found error' do
            expect(result).to be_error
            expect(result.message).to eq('Ref does not exist in repository')
          end
        end
      end
    end

    context 'when current_user is nil (internal usage)' do
      it 'bypasses permission checks and ref validation' do
        # This tests the existing behavior for internal usage
        expect(result).to be_success
      end
    end

    context 'when tracked context already exists' do
      let_it_be(:existing_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: project.default_branch,
          context_type: :branch)
      end

      context 'when context is tracked' do
        it_behaves_like 'existing tracked context'
      end

      context 'when context is not tracked' do
        before_all do
          existing_context.untrack!
        end

        context 'when allow_untracked is false' do
          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to eq('Context is not tracked')
          end
        end

        context 'when allow_untracked is true' do
          let(:allow_untracked) { true }

          it_behaves_like 'existing tracked context'
        end
      end
    end

    context 'when tracked context does not exist' do
      context 'when is_default is true' do
        let(:is_default) { true }

        it_behaves_like 'context creation'

        context 'when tracked refs limit is exceeded' do
          let(:max_refs) { 1 }

          before do
            stub_feature_flags(vac_increased_limit: false)
            stub_const('Security::ProjectTrackedContext::MAX_TRACKED_REFS_PER_PROJECT', max_refs)
            create(:security_project_tracked_context, :tracked, project: project)
          end

          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to include("cannot exceed #{max_refs} tracked refs per project")
          end

          it 'does not create a tracked context' do
            expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
          end
        end
      end

      context 'when is_default is false' do
        let(:is_default) { false }

        context 'when allow_untracked is false' do
          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to eq('Expected context to already exist for non-default branches')
          end

          it 'does not create a tracked context' do
            expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
          end
        end

        context 'when allow_untracked is true' do
          let(:allow_untracked) { true }

          it_behaves_like 'context creation'
        end
      end

      context 'when is_default is nil' do
        let(:is_default) { nil }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Expected context to already exist for non-default branches')
        end

        it 'does not create a tracked context' do
          expect { service.execute }.not_to change { Security::ProjectTrackedContext.count }
        end
      end
    end

    context 'when finding existing context by different attributes' do
      let_it_be(:branch_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'develop',
          context_type: :branch)
      end

      let_it_be(:tag_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: 'develop',
          context_type: :tag)
      end

      context 'when searching for a branch context' do
        let(:context_name) { 'develop' }
        let(:context_type) { :branch }

        it 'finds the branch context, not the tag context' do
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to eq(branch_context)
        end
      end

      context 'when searching for a tag context' do
        let(:context_name) { 'develop' }
        let(:context_type) { :tag }

        it 'finds the tag context, not the branch context' do
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to eq(tag_context)
        end
      end
    end

    context 'when multiple projects have contexts with the same name' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_project_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: other_project,
          context_name: 'main',
          context_type: :branch)
      end

      it 'only finds contexts for the specified project' do
        expect(result).to be_success
        tracked_context = result.payload[:tracked_context]
        expect(tracked_context).to be_persisted
        expect(tracked_context.project).to eq(project)
        expect(tracked_context).not_to eq(other_project_context)
      end
    end

    context 'when ingesting for a default branch' do
      context 'when default context exists but the context_name differs' do
        let_it_be(:existing_context) do
          create(:security_project_tracked_context,
            :tracked,
            project: project,
            context_name: 'old_default',
            context_type: :branch,
            is_default: true
          )
        end

        let_it_be(:existing_context_2) do
          create(:security_project_tracked_context,
            :tracked,
            project: project,
            context_name: 'old_default_2',
            context_type: :branch,
            is_default: true
          )
        end

        it 'updates the latest default existing context', :aggregate_failures do
          expect { service.execute }
          .to not_change { Security::ProjectTrackedContext.count }
          .and not_change { existing_context.reload.context_name }

          existing_context_2.reload
          expect(existing_context_2.context_name).to eq(project.default_branch)
          expect(existing_context_2.context_type).to eq('branch')
          expect(existing_context_2.is_default).to be(true)
          expect(existing_context_2.project).to eq(project)
        end
      end
    end
  end

  describe '#ref_exists_in_repository?' do
    subject(:ref_exists) { service.send(:ref_exists_in_repository?) }

    context 'when repository does not exist' do
      before do
        allow(project).to receive(:repository_exists?).and_return(false)
      end

      it 'returns false' do
        expect(ref_exists).to be false
      end
    end

    context 'when repository exists' do
      before do
        allow(project).to receive(:repository_exists?).and_return(true)
      end

      context 'when context_type is branch' do
        let(:context_type) { :branch }

        it 'checks branch existence' do
          expect(project.repository).to receive(:branch_exists?).with(context_name)
          ref_exists
        end
      end

      context 'when context_type is tag' do
        let(:context_type) { :tag }

        it 'checks tag existence' do
          expect(project.repository).to receive(:tag_exists?).with(context_name)
          ref_exists
        end
      end

      context 'when context_type is invalid' do
        let(:context_type) { :invalid_type }

        it 'returns false for unknown context types' do
          expect(ref_exists).to be false
        end
      end
    end
  end
end
