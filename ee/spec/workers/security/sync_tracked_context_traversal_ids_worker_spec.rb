# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncTrackedContextTraversalIdsWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:tracked_context) do
    create(:security_project_tracked_context, :tracked, project: project)
  end

  let(:job_args) { project.id }

  subject(:perform) { described_class.new.perform(job_args) }

  it_behaves_like 'an idempotent worker'

  it 'changes the traversal_ids of the record' do
    tracked_context.update_column(:traversal_ids, [])

    expect { perform }.to change { tracked_context.reload.traversal_ids }.from([]).to(project.namespace.traversal_ids)
  end
end
