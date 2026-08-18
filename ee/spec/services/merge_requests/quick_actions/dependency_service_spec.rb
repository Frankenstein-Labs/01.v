# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::QuickActions::DependencyService, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:other_merge_request) { create(:merge_request, :unique_branches, source_project: project) }

  subject(:service) { described_class.new(merge_request, user, project) }

  describe '#can_block?' do
    context 'when the feature is licensed' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      it 'returns true for a user who can update the merge request' do
        expect(service.can_block?).to be(true)
      end

      context 'when the user cannot update the merge request' do
        let_it_be(:other_user) { create(:user) }

        subject(:service) { described_class.new(merge_request, other_user, project) }

        it 'returns false' do
          expect(service.can_block?).to be(false)
        end
      end
    end

    context 'when the feature is not licensed' do
      before do
        stub_licensed_features(blocking_merge_requests: false)
      end

      it 'returns false' do
        expect(service.can_block?).to be(false)
      end
    end

    context 'when the merge request is not persisted' do
      let(:new_mr) { build(:merge_request, source_project: project) }

      subject(:service) { described_class.new(new_mr, user, project) }

      it 'returns false' do
        expect(service.can_block?).to be(false)
      end
    end
  end

  describe '#can_admin_link?' do
    before do
      stub_licensed_features(blocking_merge_requests: true)
    end

    it 'delegates to can_block?' do
      expect(service.can_admin_link?).to eq(service.can_block?)
    end
  end

  describe '#param_hint' do
    it 'returns the merge request reference hint' do
      expect(service.param_hint).to eq('<!merge_request | group/project!merge_request | merge request URL>')
    end
  end

  describe '#type_name' do
    it 'returns merge request' do
      expect(service.type_name).to eq('merge request')
    end
  end

  describe '#parse_params' do
    it 'extracts merge request references from text' do
      refs = service.parse_params(other_merge_request.to_reference)
      expect(refs).to contain_exactly(other_merge_request)
    end
  end

  describe '#format_ref' do
    it 'returns the reference relative to the target project' do
      expect(service.format_ref(other_merge_request)).to eq(other_merge_request.to_reference(project))
    end
  end

  describe '#format_refs' do
    it 'returns a sentence of references' do
      result = service.format_refs([other_merge_request])
      expect(result).to eq(other_merge_request.to_reference(project))
    end
  end

  describe '#create_link' do
    before do
      stub_licensed_features(blocking_merge_requests: true)
    end

    context 'with blocks link type' do
      it 'creates a block where the target blocks the given merge request' do
        expect { service.create_link([other_merge_request], link_type: 'blocks') }
          .to change { MergeRequestBlock.count }.by(1)

        block = MergeRequestBlock.last
        expect(block.blocking_merge_request).to eq(merge_request)
        expect(block.blocked_merge_request).to eq(other_merge_request)
      end
    end

    context 'with is_blocked_by link type' do
      it 'creates a block where the given merge request blocks the target' do
        expect { service.create_link([other_merge_request], link_type: 'is_blocked_by') }
          .to change { MergeRequestBlock.count }.by(1)

        block = MergeRequestBlock.last
        expect(block.blocking_merge_request).to eq(other_merge_request)
        expect(block.blocked_merge_request).to eq(merge_request)
      end
    end
  end

  describe '#destroy_link' do
    let_it_be(:block) do
      create(:merge_request_block,
        blocking_merge_request: other_merge_request,
        blocked_merge_request: merge_request)
    end

    it 'destroys the block between merge requests' do
      expect { service.destroy_link(other_merge_request) }
        .to change { MergeRequestBlock.count }.by(-1)
    end

    context 'when no block exists' do
      let_it_be(:unlinked_mr) { create(:merge_request, :unique_branches, source_project: project) }

      it 'does nothing' do
        expect { service.destroy_link(unlinked_mr) }
          .not_to change { MergeRequestBlock.count }
      end
    end
  end
end
