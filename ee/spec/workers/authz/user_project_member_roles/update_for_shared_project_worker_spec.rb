# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker, feature_category: :permissions do
  let_it_be(:link) { create(:project_group_link) }

  let(:job_args) { [link.id] }
  let(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform(job_args) }

    it 'executes Authz::UserProjectMemberRoles::UpdateForSharedProjectService' do
      expect_next_instance_of(Authz::UserProjectMemberRoles::UpdateForSharedProjectService, link) do |s|
        expect(s).to receive(:execute)
      end

      perform
    end

    context 'when project_group_link does not exist' do
      let(:job_args) { [non_existing_record_id] }

      it 'does not call the service' do
        expect(Authz::UserProjectMemberRoles::UpdateForSharedProjectService).not_to receive(:new)

        perform
      end
    end
  end
end
