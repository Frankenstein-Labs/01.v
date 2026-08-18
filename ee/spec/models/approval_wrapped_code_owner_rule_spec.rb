# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalWrappedCodeOwnerRule, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  subject { described_class.new(merge_request, rule) }

  let(:merge_request) { create(:merge_request) }
  let(:approver_count) { 1 }
  let(:approvals_required) { 5 }

  let!(:rule) do
    create(
      :code_owner_rule,
      merge_request: merge_request,
      users: create_list(:user, approver_count),
      approvals_required: approvals_required
    )
  end

  describe '#finalize!' do
    it 'updates the approvals_required to 0' do
      expect { subject.finalize! }.to change { rule.approvals_required }
        .from(5).to(0)
    end
  end

  describe '#approvals_required' do
    context 'when merge request is merged and approval not required' do
      before do
        merge_request.mark_as_merged!
      end

      it 'returns 0' do
        expect(subject.approvals_required).to eq(5)
      end
    end

    context 'when merge request is not merged' do
      let_it_be_with_reload(:merge_request) { create(:merge_request) }

      where(:branch_requires, :optional_section, :approver_count, :approvals_required, :expected_required_approvals) do
        true  | false | 0 | 0 | 0
        true  | false | 2 | 0 | 1
        true  | true  | 2 | 0 | 0
        true  | false | 0 | 2 | 0
        true  | false | 2 | 2 | 2
        false | false | 2 | 0 | 0
        false | false | 0 | 0 | 0
      end

      with_them do
        let(:branch) { subject.project.repository.branches.find { |b| b.name == merge_request.target_branch } }

        context "when project.code_owner_approval_required_available? is true" do
          before do
            allow(subject.project)
              .to receive(:code_owner_approval_required_available?).and_return(true)
            allow(Gitlab::CodeOwners).to receive(:optional_section?).and_return(optional_section)
          end

          it 'checks the rule is in an optional codeowners section' do
            subject.approvals_required
            # If the repo includes `refs/heads/develop` and `refs/tags/develop`,
            # passing `ref = 'develop'` will return the `CODEOWNER` file in `refs/tags/develop`
            # when we actually want to reference the branch. To prevent this we
            # pass `merge_request.target_branch_ref`.
            expect(Gitlab::CodeOwners).to have_received(:optional_section?).with(subject.project, merge_request.target_branch_ref, rule.section)
          end

          context "when the project doesn't require code owner approval on all MRs" do
            it 'returns the expected number of approvals for protected_branches that do require approval' do
              allow(subject.project)
                .to receive(:merge_requests_require_code_owner_approval?).and_return(false)
              allow(ProtectedBranch)
                .to receive(:branch_requires_code_owner_approval?).with(subject.project,
                  branch.name).and_return(branch_requires)

              expect(subject.approvals_required).to eq(expected_required_approvals)
            end
          end
        end

        context "when project.code_owner_approval_required_available? is falsy" do
          it "returns nil" do
            allow(subject.project)
              .to receive(:code_owner_approval_required_available?).and_return(false)

            expect(subject.approvals_required).to eq(0)
          end
        end
      end
    end
  end
end
