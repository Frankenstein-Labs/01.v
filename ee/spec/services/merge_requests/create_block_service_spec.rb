# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateBlockService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:private_project) { create(:project, :private) }
  let_it_be_with_refind(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be_with_refind(:blocking_merge_request) do
    create(:merge_request, :unique_branches, source_project: project, target_project: project)
  end

  let(:service) do
    described_class.new(user: user, merge_request: merge_request, blocking_merge_request_id:
                                      blocking_merge_request_id)
  end

  let(:blocking_merge_request_id) { blocking_merge_request.id }
  let(:user) { merge_request.author }
  let(:result) { service.execute }

  describe '#execute' do
    it 'creates a block' do
      expect { result }.to change { MergeRequestBlock.count }.by(1)

      expect(result).to be_success
      expect(result.payload[:merge_request_block]).to have_attributes(
        blocking_merge_request_id: blocking_merge_request_id, blocked_merge_request_id: merge_request.id)
    end

    it 'creates blocking system note on the blocking merge request' do
      result

      note = blocking_merge_request.notes.last
      expect(note.note).to eq("marked this merge request as blocking #{merge_request.to_reference(project)}")
    end

    it 'creates blocked-by system note on the blocked merge request' do
      result

      note = merge_request.notes.last
      expect(note.note).to eq("marked this merge request as blocked by #{blocking_merge_request.to_reference(project)}")
    end

    context 'when the blocking mr is not found' do
      let(:blocking_merge_request_id) { non_existing_record_id }

      it 'returns a service error with not found' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Blocking merge request not found', reason: :not_found)
      end
    end

    context 'when the user lacks permissions for the blocking mr' do
      let!(:blocking_merge_request) do
        create(:merge_request, :unique_branches, source_project: private_project, target_project: private_project)
      end

      it 'returns a service error with forbidden' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Lacking permissions to the blocking merge request',
          reason: :forbidden)
      end
    end

    context 'when the user lacks permissions for merge request' do
      let!(:blocking_merge_request) do
        create(:merge_request, :unique_branches, source_project: private_project, target_project: private_project)
      end

      let(:user) { create(:user) }

      it 'returns a service error with forbidden' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Lacking permissions to update the merge request',
          reason: :forbidden)
      end
    end

    context 'when the block already exists' do
      before do
        ::MergeRequestBlock.create!(
          blocking_merge_request_id: blocking_merge_request_id,
          blocked_merge_request_id: merge_request.id
        )
      end

      it 'returns a service error with conflict' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Block already exists', reason: :conflict)
      end
    end

    context 'when the block fails to save' do
      let(:blocking_merge_request_id) { merge_request.id }

      it 'returns a service error with bad request' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'This block is self-referential', reason: :bad_request)
      end
    end

    context 'when the blocked MR organization is isolated' do
      let_it_be(:organization) do
        create(:organization).tap(&:mark_as_isolated!)
      end

      let_it_be(:org_project) { create(:project, :repository, organization: organization) }
      let_it_be(:merge_request) do
        create(:merge_request, :unique_branches, source_project: org_project, target_project: org_project)
      end

      let_it_be(:user) { merge_request.author }

      context 'when the blocking MR belongs to a different organization' do
        let(:other_organization) { create(:organization) }
        let(:other_project) { create(:project, :repository, :public, organization: other_organization) }
        let(:blocking_merge_request) do
          create(:merge_request, :unique_branches, source_project: other_project, target_project: other_project)
        end

        let(:blocking_merge_request_id) { blocking_merge_request.id }

        it 'returns a service error with bad request' do
          expect { result }.not_to change { MergeRequestBlock.count }

          expect(result).to be_error
          expect(result).to have_attributes(
            message: 'The blocking merge request must be in the same organization',
            reason: :bad_request
          )
        end
      end

      context 'when the blocking MR belongs to the same organization' do
        let(:another_org_project) { create(:project, :repository, :public, organization: organization) }
        let(:blocking_merge_request) do
          create(:merge_request, :unique_branches, source_project: another_org_project,
            target_project: another_org_project)
        end

        let(:blocking_merge_request_id) { blocking_merge_request.id }

        it 'creates the block' do
          expect { result }.to change { MergeRequestBlock.count }.by(1)

          expect(result).to be_success
        end
      end
    end
  end
end
