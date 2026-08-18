# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRoles::DestroyForSharedProjectWorker, feature_category: :permissions do
  let_it_be(:shared_project) { create(:project) }
  let_it_be(:shared_with_group) { create(:group) }

  let(:job_args) { [shared_project.id, shared_with_group.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform(*job_args) }

    it 'executes Authz::UserProjectMemberRole::DestroyForSharedProjectService' do
      expect_next_instance_of(Authz::UserProjectMemberRoles::DestroyForSharedProjectService, shared_project,
        shared_with_group) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when project does not exist' do
      let(:job_args) { [non_existing_record_id, shared_with_group.id] }

      it 'does not call the service' do
        expect(Authz::UserProjectMemberRoles::DestroyForSharedProjectService).not_to receive(:new)

        perform
      end
    end

    context 'when group does not exist' do
      let(:job_args) { [shared_project.id, non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserProjectMemberRoles::DestroyForSharedProjectService).not_to receive(:new)

        perform
      end
    end
  end
end
