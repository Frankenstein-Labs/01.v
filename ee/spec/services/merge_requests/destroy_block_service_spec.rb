# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::DestroyBlockService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:blocking_merge_request) { create(:merge_request, :unique_branches, source_project: project) }
  let_it_be_with_refind(:block) do
    create(:merge_request_block,
      blocking_merge_request: blocking_merge_request,
      blocked_merge_request: merge_request)
  end

  let(:user) { merge_request.author }
  let(:service) { described_class.new(user: user, block: block) }

  describe '#execute' do
    it 'destroys the block' do
      expect { service.execute }.to change { MergeRequestBlock.count }.by(-1)
    end

    it 'creates system notes on both merge requests' do
      service.execute

      expect(blocking_merge_request.notes.last.note)
        .to eq("removed the relation with #{merge_request.to_reference(project)}")
      expect(merge_request.notes.last.note)
        .to eq("removed the relation with #{blocking_merge_request.to_reference(project)}")
    end

    context 'when user lacks permissions' do
      let_it_be(:user) { create(:user) }

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Lacking permissions to update the merge request',
          reason: :forbidden)
      end

      it 'does not destroy the block' do
        expect { service.execute }.not_to change { MergeRequestBlock.count }
      end
    end
  end
end
