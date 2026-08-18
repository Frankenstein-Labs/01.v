# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::WorkspaceProjectService, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  subject(:service) { described_class.new(namespace: group, current_user: user) }

  describe '#execute' do
    context 'when namespace is nil' do
      subject(:service) { described_class.new(namespace: nil, current_user: user) }

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Namespace is required.')
      end
    end

    context 'when current_user is nil' do
      subject(:service) { described_class.new(namespace: group, current_user: nil) }

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('User is required.')
      end
    end

    context 'when current_user does not have access to the namespace' do
      let_it_be(:non_member) { create(:user) }

      subject(:service) { described_class.new(namespace: group, current_user: non_member) }

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('do not have access')
      end

      context 'when the workspace project already exists' do
        before do
          create(:project, namespace: group, path: 'duo-workspace')
        end

        it 'returns an error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('do not have access')
        end
      end
    end

    context 'when Duo Agent Platform is not available for the namespace' do
      before_all do
        group.add_developer(user)
      end

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, group).and_return(false)
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('Duo Agent Platform is not available')
      end

      it 'does not create a project' do
        expect { service.execute }.not_to change { Project.count }
      end
    end

    context 'when workspace project already exists' do
      let_it_be(:project) { create(:project, namespace: group, path: 'duo-workspace') }

      before_all do
        group.add_guest(user)
      end

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, group).and_return(true)
      end

      it 'returns the existing project' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:project]).to eq(project)
      end

      it 'does not create a new project' do
        expect { service.execute }.not_to change { Project.count }
      end
    end

    context 'when workspace project does not exist' do
      before_all do
        group.add_owner(user)
      end

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:duo_workflow, group).and_return(true)
      end

      it 'creates a new private project' do
        result = service.execute

        expect(result).to be_success
        project = result.payload[:project]
        expect(project.path).to eq('duo-workspace')
        expect(project.name).to eq('Duo Workspace')
        expect(project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
        expect(project.namespace).to eq(group)
      end

      it 'initializes project with a README containing customization docs' do
        result = service.execute
        project = result.payload[:project]

        readme = project.repository.blob_at(project.default_branch, 'README.md')
        expect(readme).to be_present
        expect(readme.data).to include('Duo Workspace')
        expect(readme.data).to include('default execution environment')
        expect(readme.data).to include('AGENTS.md')
        expect(readme.data).to include('agent-config.yml')
      end

      it 'disables unnecessary features' do
        result = service.execute
        project = result.payload[:project]

        expect(project.container_registry_enabled).to be false
        expect(project.packages_enabled).to be false
        expect(project.wiki_enabled?).to be false
        expect(project.snippets_enabled?).to be false
      end

      it 'enables CI/CD builds' do
        result = service.execute
        project = result.payload[:project]

        expect(project.builds_enabled?).to be true
      end

      context 'when user has namespace access but not project creation permission' do
        let_it_be(:guest_user) { create(:user) }

        before_all do
          group.add_guest(guest_user)
        end

        before do
          allow(guest_user).to receive(:can?).and_call_original
          allow(guest_user).to receive(:can?).with(:duo_workflow, group).and_return(true)
        end

        subject(:service) { described_class.new(namespace: group, current_user: guest_user) }

        it 'returns an error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('permission')
        end
      end

      context 'when a concurrent request creates the project (race condition)' do
        it 'handles RecordNotUnique by retrying the lookup' do
          existing_project = create(:project, namespace: group, path: 'duo-workspace')

          allow(::Projects::CreateService).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)

          result = service.execute

          expect(result).to be_success
          expect(result.payload[:project]).to eq(existing_project)
        end

        it 'returns an error if the retry lookup also fails' do
          allow(::Projects::CreateService).to receive(:new).and_raise(ActiveRecord::RecordNotUnique)

          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('conflict')
        end
      end
    end
  end
end
