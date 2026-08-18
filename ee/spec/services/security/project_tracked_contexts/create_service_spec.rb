# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::CreateService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:context_name) { 'master' }
  let(:context_type) { :branch }
  let(:is_default) { false }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    Security::ProjectTrackedContext.where(project: project).delete_all
  end

  describe '#execute' do
    let(:service) do
      described_class.new(
        project: project,
        context_name: context_name,
        context_type: context_type,
        is_default: is_default
      )
    end

    subject(:result) { service.execute }

    context 'with valid parameters' do
      context 'when ref exists in repository' do
        let(:context_name) { 'feature' }

        context 'when tracked context does not exist' do
          it 'creates a new tracked context' do
            expect { result }.to change { Security::ProjectTrackedContext.count }.by(1)

            expect(result).to be_success

            tracked_context = result.payload[:tracked_context]
            expect(tracked_context).to have_attributes(
              project: project,
              context_name: 'feature',
              context_type: 'branch',
              is_default: false,
              state: Security::ProjectTrackedContext::STATES[:tracked],
              uuid_version: Security::ProjectTrackedContext::CONTEXT_AWARE_UUID_VERSION
            )
          end

          it 'sets traversal_ids from project namespace' do
            tracked_context = result.payload[:tracked_context]

            expect(tracked_context.traversal_ids).to eq(project.namespace.traversal_ids)
          end

          it 'logs the creation of the tracked context' do
            expect(Gitlab::AppJsonLogger).to receive(:info).with(
              hash_including(
                'class_name' => described_class.name,
                'message' => 'Security tracked context created',
                'gl_project_id' => project.id,
                'context_name' => 'feature',
                'context_type' => 'branch',
                'is_default' => false
              )
            )

            result
          end

          context 'when is_default is true' do
            let(:is_default) { true }

            it 'creates tracked context with is_default true' do
              expect(result).to be_success
              expect(result.payload[:tracked_context]).to have_attributes(
                is_default: true
              )
            end
          end
        end

        context 'when tracked context already exists' do
          let(:context_name) { 'feature' }

          let!(:existing_context) do
            create(:security_project_tracked_context,
              project: project,
              context_name: 'feature',
              context_type: :branch,
              is_default: false
            )
          end

          it 'returns an error for duplicate context' do
            expect { result }.not_to change { Security::ProjectTrackedContext.count }

            expect(result).to be_error
            expect(result.message).to include('already been taken')
          end
        end
      end

      context 'when ref does not exist in repository' do
        let(:context_name) { 'non-existent-branch' }

        it 'returns an error' do
          expect(result).to be_error
          expect(result.message).to eq('Ref does not exist in repository')
        end

        it 'does not create a tracked context' do
          expect { result }.not_to change { Security::ProjectTrackedContext.count }
        end
      end

      context 'with tag context type' do
        let(:context_type) { :tag }
        let(:context_name) { 'v1.1.0' }

        it 'creates a tracked context for tag' do
          expect(result).to be_success
          expect(result.payload[:tracked_context]).to have_attributes(
            context_name: 'v1.1.0',
            context_type: 'tag'
          )
        end

        context 'when tag does not exist' do
          let(:context_name) { 'non-existent-tag' }

          it 'returns an error' do
            expect(result).to be_error
            expect(result.message).to eq('Ref does not exist in repository')
          end
        end
      end
    end

    context 'when repository does not exist' do
      before do
        allow(project).to receive(:repository_exists?).and_return(false)
      end

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Ref does not exist in repository')
      end
    end

    context 'when context_type is invalid' do
      let(:context_type) { :invalid_type }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Ref does not exist in repository')
      end

      it 'does not create a tracked context' do
        expect { result }.not_to change { Security::ProjectTrackedContext.count }
      end
    end

    context 'when database validation fails' do
      before do
        allow(project.repository).to receive(:branch_exists?).and_return(true)
        allow(Security::ProjectTrackedContext).to receive(:create).and_return(
          instance_double(Security::ProjectTrackedContext,
            persisted?: false,
            errors: instance_double(ActiveModel::Errors,
              full_messages: ['Context name has already been taken']
            )
          )
        )
      end

      it 'returns an error with validation messages' do
        expect(result).to be_error
        expect(result.message).to eq('Context name has already been taken')
      end
    end

    context 'when multiple validation errors occur' do
      before do
        allow(project.repository).to receive(:branch_exists?).and_return(true)
        allow(Security::ProjectTrackedContext).to receive(:create).and_return(
          instance_double(Security::ProjectTrackedContext,
            persisted?: false,
            errors: instance_double(ActiveModel::Errors,
              full_messages: ['Context name has already been taken', 'Project must exist']
            )
          )
        )
      end

      it 'returns concatenated error messages' do
        expect(result).to be_error
        expect(result.message).to eq('Context name has already been taken, Project must exist')
      end
    end
  end

  describe 'repository interaction' do
    let(:service) do
      described_class.new(
        project: project,
        context_name: context_name,
        context_type: context_type,
        is_default: is_default
      )
    end

    subject(:result) { service.execute }

    context 'when checking branch existence' do
      let(:context_type) { :branch }
      let(:context_name) { 'master' }

      it 'calls repository.branch_exists? with correct parameters' do
        allow(project.repository).to receive(:branch_exists?).with('master').and_return(false)

        expect(result).to be_error
        expect(result.message).to eq('Ref does not exist in repository')
      end
    end

    context 'when checking tag existence' do
      let(:context_type) { :tag }
      let(:context_name) { 'v1.1.0' }

      it 'calls repository.tag_exists? with correct parameters' do
        allow(project.repository).to receive(:tag_exists?).with('v1.1.0').and_return(false)

        expect(result).to be_error
        expect(result.message).to eq('Ref does not exist in repository')
      end
    end
  end
end
