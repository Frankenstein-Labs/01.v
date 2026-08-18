# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestBlock, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:blocking_merge_request).class_name('MergeRequest') }
    it { is_expected.to belong_to(:blocked_merge_request).class_name('MergeRequest') }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject(:block) { create(:merge_request_block) }

    let(:blocking_mr) { block.blocking_merge_request }
    let(:blocked_mr) { block.blocked_merge_request }
    let(:another_mr) { create(:merge_request) }

    it { is_expected.to validate_presence_of(:blocking_merge_request) }
    it { is_expected.to validate_presence_of(:blocked_merge_request) }

    it 'forbids the blocking MR from being the blocked MR' do
      block.blocking_merge_request = block.blocked_merge_request

      expect(block).not_to be_valid
    end

    it 'allows an MR to block multiple MRs' do
      another_block = described_class.new(
        blocking_merge_request: blocking_mr,
        blocked_merge_request: another_mr
      )

      expect(another_block).to be_valid
    end

    it 'limits the number of blocking MRs to MAX_BLOCKED_BY_COUNT' do
      expect(block).to receive(:blocked_by_count).and_return(MergeRequestBlock::MAX_BLOCKED_BY_COUNT)
      expect(block).not_to be_valid
    end

    it 'limits the number of blocked MRs to MAX_BLOCKS_COUNT' do
      expect(block).to receive(:blocks_count).and_return(MergeRequestBlock::MAX_BLOCKS_COUNT)
      expect(block).not_to be_valid
    end

    it 'allows an MR to be blocked by multiple MRs' do
      another_block = described_class.new(
        blocking_merge_request: another_mr,
        blocked_merge_request: blocked_mr
      )

      expect(another_block).to be_valid
    end

    it 'allows blocks to be intra-project' do
      project = blocking_mr.target_project
      intra_project_mr = create(:merge_request, :rebased, source_project: project, target_project: project)
      block.blocked_merge_request = intra_project_mr

      is_expected.to be_valid
    end

    context 'when the blocked MR organization is isolated' do
      let_it_be(:organization) do
        create(:organization).tap(&:mark_as_isolated!)
      end

      let_it_be(:project_in_org) { create(:project, :repository, organization: organization) }
      let_it_be(:blocked_mr_in_org) do
        create(:merge_request, :unique_branches, source_project: project_in_org, target_project: project_in_org)
      end

      context 'when the blocking MR is from a different organization' do
        let(:other_organization) { create(:organization) }
        let(:other_project) { create(:project, :repository, organization: other_organization) }
        let(:blocking_mr_cross_org) do
          create(:merge_request, :unique_branches, source_project: other_project, target_project: other_project)
        end

        it 'is invalid', :aggregate_failures do
          cross_org_block = described_class.new(
            blocking_merge_request: blocking_mr_cross_org,
            blocked_merge_request: blocked_mr_in_org
          )

          expect(cross_org_block).not_to be_valid
          expect(cross_org_block.errors.full_messages)
            .to include('The blocking merge request must be in the same organization')
        end
      end

      context 'when the blocking MR is from the same organization' do
        let(:another_project_in_org) { create(:project, :repository, organization: organization) }
        let(:blocking_mr_same_org) do
          create(:merge_request, :unique_branches, source_project: another_project_in_org,
            target_project: another_project_in_org)
        end

        it 'is valid' do
          same_org_block = described_class.new(
            blocking_merge_request: blocking_mr_same_org,
            blocked_merge_request: blocked_mr_in_org
          )

          expect(same_org_block).to be_valid
        end
      end
    end

    context 'when the blocked MR organization is not isolated' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:project_in_org) { create(:project, :repository, organization: organization) }
      let_it_be(:blocked_mr_in_org) do
        create(:merge_request, :unique_branches, source_project: project_in_org, target_project: project_in_org)
      end

      context 'when the blocking MR is from a different organization' do
        let(:other_organization) { create(:organization) }
        let(:other_project) { create(:project, :repository, organization: other_organization) }
        let(:blocking_mr_cross_org) do
          create(:merge_request, :unique_branches, source_project: other_project, target_project: other_project)
        end

        it 'is valid' do
          cross_org_block = described_class.new(
            blocking_merge_request: blocking_mr_cross_org,
            blocked_merge_request: blocked_mr_in_org
          )

          expect(cross_org_block).to be_valid
        end
      end

      context 'when the blocking MR is from the same organization' do
        let(:another_project_in_org) { create(:project, :repository, organization: organization) }
        let(:blocking_mr_same_org) do
          create(:merge_request, :unique_branches, source_project: another_project_in_org,
            target_project: another_project_in_org)
        end

        it 'is valid' do
          same_org_block = described_class.new(
            blocking_merge_request: blocking_mr_same_org,
            blocked_merge_request: blocked_mr_in_org
          )

          expect(same_org_block).to be_valid
        end
      end
    end

    it 'forbids duplicate blocks' do
      new_block = described_class.new(block.attributes)

      expect(new_block).not_to be_valid
    end

    it 'allows a blocking MR to become blocked' do
      new_block = build(:merge_request_block, blocked_merge_request: block.blocking_merge_request)

      expect(new_block).to be_valid
    end

    it 'allows a blocked MR to become a blocker' do
      new_block = build(:merge_request_block, blocking_merge_request: block.blocked_merge_request)

      expect(new_block).to be_valid
    end
  end

  describe '.with_blocking_mr_ids' do
    let!(:block) { create(:merge_request_block) }
    let!(:other_block) { create(:merge_request_block) }

    subject(:result) { described_class.with_blocking_mr_ids([block.blocking_merge_request_id]) }

    it 'returns blocks with a matching blocking_merge_request_id' do
      is_expected.to contain_exactly(block)
    end

    it 'eager-loads the blocking MRs' do
      association = result.first.association(:blocking_merge_request)
      expect(association.loaded?).to be(true)
    end
  end

  describe '.for_merge_requests' do
    let!(:block) { create(:merge_request_block) }
    let(:mr1) { block.blocking_merge_request }
    let(:mr2) { block.blocked_merge_request }

    it 'finds a block when mr1 is the blocker' do
      expect(described_class.for_merge_requests(mr1, mr2)).to eq(block)
    end

    it 'finds a block when mr1 is the blockee' do
      expect(described_class.for_merge_requests(mr2, mr1)).to eq(block)
    end

    it 'returns nil when no block exists' do
      expect(described_class.for_merge_requests(mr1, create(:merge_request))).to be_nil
    end
  end
end
