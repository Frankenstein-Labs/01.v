# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::RestoreService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be_with_reload(:project) do
    create(:project,
      :repository,
      :aimed_for_deletion,
      path: 'project-1-deletion_scheduled-177483',
      name: 'Project1 Name-deletion_scheduled-177483',
      namespace: user.namespace,
      deleting_user: user)
  end

  context 'for audit events' do
    it 'saves audit event' do
      # Stub .audit here so that only relevant audit events are received below
      allow(::Gitlab::Audit::Auditor).to receive(:audit)

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_path_updated')
      ).and_call_original

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_name_updated')
      ).and_call_original

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'project_restored')
      ).and_call_original

      expect { described_class.new(project, user).execute }
        .to change { AuditEventReader.count }.by(3)
    end
  end
end
