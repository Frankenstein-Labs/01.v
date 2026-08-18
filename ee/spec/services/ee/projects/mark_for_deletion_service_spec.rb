# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }

  subject(:result) { described_class.new(project, user).execute }

  shared_examples 'marks project for deletion' do
    it 'marks the project for deletion' do
      expect { result }.to change { project.self_deletion_scheduled? }.from(false).to(true)
    end
  end

  shared_examples 'security policy project' do
    context 'when attempting to mark security policy project for deletion' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'errors' do
        expect(result).to be_error
        expect(result.message).to eq('Project cannot be deleted because it is linked as a security policy project')
      end

      it "doesn't mark the project for deletion" do
        expect { result }.not_to change { project.self_deletion_scheduled? }.from(false)
      end

      context 'without licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'marks project for deletion'
      end
    end
  end

  context 'with group namespace' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) do
      create(:project, namespace: group)
    end

    before_all do
      group.add_owner(user)
    end

    it_behaves_like 'security policy project'

    context 'for audit events' do
      it 'saves audit event with group as scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_path_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_name_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'project_deletion_marked',
            author: user,
            scope: group,
            target: project,
            message: 'Project marked for deletion',
            additional_details: {
              project_id: project.id,
              namespace_id: project.namespace_id,
              root_namespace_id: project.root_namespace.id
            }
          )
        ).and_call_original

        expect { result }.to change { AuditEventReader.count }.by(3)
      end
    end
  end

  context 'with user namespace' do
    let_it_be_with_reload(:project) do
      create(:project, namespace: user.namespace)
    end

    it_behaves_like 'security policy project'

    context 'for audit events' do
      it 'saves audit event with instance scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_path_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: 'project_name_updated')
        ).and_call_original

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'project_deletion_marked',
            author: user,
            scope: instance_of(::Gitlab::Audit::InstanceScope),
            target: project,
            message: 'Project marked for deletion',
            additional_details: {
              project_id: project.id,
              namespace_id: project.namespace_id,
              root_namespace_id: project.root_namespace.id
            }
          )
        ).and_call_original

        expect { result }.to change { AuditEventReader.count }.by(3)
      end
    end
  end
end
