# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ExternalStatusCheck, type: :model do
  subject { build(:external_status_check) }

  describe 'Associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_and_belong_to_many(:protected_branches) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:external_url) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
    it { is_expected.to validate_uniqueness_of(:external_url).scoped_to(:project_id) }
    it { is_expected.to validate_length_of(:shared_secret).is_at_most(255) }

    specify 'shared_secret length validation does not invalidate existing records' do
      external_status_check = create(:external_status_check)
      external_status_check.shared_secret = 'A' * 260
      external_status_check.save!(validate: false)

      expect(external_status_check.reload).to be_valid
    end

    describe 'protected_branches_must_belong_to_project_or_group_hierarchy' do
      let_it_be(:group, freeze: false) { create(:group) }
      let_it_be(:project, freeze: false) { create(:project, group: group) }

      let(:check) { build(:external_status_check, project: project, protected_branches: [protected_branch]) }

      subject(:error_messages) { check.validate.then { check.errors.messages[:base] } }

      context 'with project-level protected branch' do
        context 'when branch belongs to same project' do
          let(:protected_branch) { create(:protected_branch, project: project) }

          it { is_expected.to be_empty }
        end

        context 'when branch belongs to other project' do
          let(:protected_branch) { create(:protected_branch, project: build(:project)) }

          it { is_expected.to contain_exactly('all protected branches must exist within the project') }
        end
      end

      context 'with group-level protected branch' do
        let(:protected_branch) { create(:protected_branch, project: nil, group: group) }

        context 'when protected branch belongs to group hierarchy' do
          it { is_expected.to be_empty }
        end

        context 'when protected branch does not belong to group hierarchy' do
          let(:group) { build(:group) }

          it { is_expected.to contain_exactly('all protected branches must exist within the project') }
        end
      end
    end
  end

  describe 'to_h' do
    it 'returns the correct information' do
      expect(subject.to_h).to eq({ id: subject.id, name: subject.name, external_url: subject.external_url })
    end
  end

  describe '.applicable_to_branch' do
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }
    let_it_be(:project, freeze: false) { merge_request.project }
    let_it_be(:target_branch) { merge_request.target_branch }
    let_it_be(:check_belonging_to_different_project) { create(:external_status_check) }
    let_it_be(:check_with_no_protected_branches, freeze: false) { create(:external_status_check, project: project, protected_branches: []) }
    let_it_be(:check_with_applicable_protected_branches, freeze: false) { create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: target_branch, project: project)]) }
    let_it_be(:check_with_non_applicable_protected_branches, freeze: false) { create(:external_status_check, project: project, protected_branches: [create(:protected_branch, name: 'testbranch', project: project)]) }

    # `let_it_be(:project)` shares the project instance across examples, so its
    # `external_status_checks` association proxy can retain records cached by
    # an earlier example. Reset it here so each example evaluates against the
    # full set of rows created in `let_it_be` (the `FilterByBranch#applicable_to_branch`
    # extension iterates the loaded proxy).
    before do
      project.external_status_checks.reset
    end

    it 'returns the correct collection of checks' do
      expect(project.external_status_checks.applicable_to_branch(target_branch)).to contain_exactly(check_with_no_protected_branches, check_with_applicable_protected_branches)
    end

    context 'with wildcard protected branches' do
      let_it_be(:check_with_matching_wildcard_branch, freeze: false) do
        create(:external_status_check,
          project: project,
          protected_branches: [create(:protected_branch, name: 'DEV*', project: project)])
      end

      let_it_be(:check_with_non_matching_wildcard_branch, freeze: false) do
        create(:external_status_check,
          project: project,
          protected_branches: [create(:protected_branch, name: 'release/*', project: project)])
      end

      it 'includes checks whose wildcard protected branch matches the target branch' do
        result = project.external_status_checks.applicable_to_branch('DEV-main')

        expect(result).to include(check_with_matching_wildcard_branch)
        expect(result).not_to include(check_with_non_matching_wildcard_branch)
      end

      it 'excludes wildcard checks when no pattern matches' do
        result = project.external_status_checks.applicable_to_branch('main')

        expect(result).not_to include(check_with_matching_wildcard_branch)
        expect(result).not_to include(check_with_non_matching_wildcard_branch)
      end

      it 'always includes checks with no protected branches ("All branches")' do
        expect(project.external_status_checks.applicable_to_branch('DEV-main'))
          .to include(check_with_no_protected_branches)
        expect(project.external_status_checks.applicable_to_branch('any-other-branch'))
          .to include(check_with_no_protected_branches)
      end
    end

    it 'evaluates wildcard matching in memory without per-check SQL' do
      # Add more checks with wildcard protected branches to ensure the
      # query count does not scale with the number of checks.
      create_list(:external_status_check, 3, project: project,
        protected_branches: [create(:protected_branch, name: 'feature/*', project: project)])

      query_count = ActiveRecord::QueryRecorder.new do
        project.external_status_checks.applicable_to_branch(target_branch)
      end.count

      # One query for `external_status_checks` + one preload for
      # `protected_branches` + one for the HABTM join table = 3.
      # We allow a small upper bound that does not depend on the number
      # of checks; if a real N+1 regression is introduced, this would
      # grow with each added check.
      expect(query_count).to be <= 3
    end
  end

  describe '#applies_to_branch?' do
    let_it_be(:project, freeze: false) { create(:project) }

    context 'when the check has no protected branches' do
      let(:check) { create(:external_status_check, project: project, protected_branches: []) }

      it 'returns true for any branch' do
        expect(check.applies_to_branch?('main')).to be(true)
        expect(check.applies_to_branch?('feature/x')).to be(true)
      end
    end

    context 'when the check has an exact-name protected branch' do
      let_it_be(:protected_branch, freeze: false) { create(:protected_branch, name: 'main', project: project) }
      let(:check) { create(:external_status_check, project: project, protected_branches: [protected_branch]) }

      it { expect(check.applies_to_branch?('main')).to be(true) }
      it { expect(check.applies_to_branch?('feature/x')).to be(false) }
    end

    context 'when the check has a wildcard protected branch' do
      let_it_be(:protected_branch, freeze: false) { create(:protected_branch, name: 'DEV*', project: project) }
      let(:check) { create(:external_status_check, project: project, protected_branches: [protected_branch]) }

      it 'returns true when the branch matches the wildcard' do
        expect(check.applies_to_branch?('DEV-main')).to be(true)
      end

      it 'returns false when the branch does not match the wildcard' do
        expect(check.applies_to_branch?('main')).to be(false)
      end
    end

    context 'when protected_branches association is preloaded' do
      let_it_be(:protected_branch, freeze: false) { create(:protected_branch, name: 'DEV*', project: project) }
      let_it_be(:check, freeze: false) { create(:external_status_check, project: project, protected_branches: [protected_branch]) }

      it 'does not issue additional SQL on repeated calls' do
        loaded_check = described_class.preload(:protected_branches).find(check.id)

        # Prime any unrelated lazy loads.
        loaded_check.applies_to_branch?('DEV-main')

        query_count = ActiveRecord::QueryRecorder.new do
          5.times { loaded_check.applies_to_branch?('DEV-main') }
        end.count

        expect(query_count).to eq(0)
      end
    end
  end

  describe 'async_execute' do
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }

    let(:data) do
      {
        object_attributes: {
          target_branch: 'test'
        }
      }
    end

    subject { check.async_execute(data) }

    context 'when list of protected branches is empty' do
      let_it_be(:check, freeze: false) { create(:external_status_check, project: merge_request.project) }

      it 'enqueues the status check' do
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).to receive(:perform_async).once

        subject
      end
    end

    context 'when data target branch matches a protected branch' do
      let_it_be(:check, freeze: false) { create(:external_status_check, project: merge_request.project, protected_branches: [create(:protected_branch, name: 'test', project: merge_request.project)]) }

      it 'enqueues the status check' do
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).to receive(:perform_async).once

        subject
      end
    end

    context 'when data target branch does not match a protected branch' do
      let_it_be(:check, freeze: false) { create(:external_status_check, project: merge_request.project, protected_branches: [create(:protected_branch, name: 'new-branch', project: merge_request.project)]) }

      it 'does not enqueue the status check' do
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).not_to receive(:perform_async)

        subject
      end
    end

    context 'when data target branch matches a wildcard protected branch' do
      let_it_be(:check, freeze: false) do
        create(:external_status_check,
          project: merge_request.project,
          protected_branches: [create(:protected_branch, name: 'tes*', project: merge_request.project)])
      end

      it 'enqueues the status check' do
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).to receive(:perform_async).once

        subject
      end
    end

    context 'when data target branch does not match a wildcard protected branch' do
      let_it_be(:check, freeze: false) do
        create(:external_status_check,
          project: merge_request.project,
          protected_branches: [create(:protected_branch, name: 'release/*', project: merge_request.project)])
      end

      it 'does not enqueue the status check' do
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).not_to receive(:perform_async)

        subject
      end
    end

    context 'when :object_attributes key is missing from data' do
      let_it_be(:check, freeze: false) { create(:external_status_check, project: merge_request.project) }

      let(:data) { {} }

      it 'logs a warning and does not enqueue the status check' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: 'ExternalStatusCheck#async_execute called with missing target_branch',
            external_status_check_id: check.id,
            project_id: check.project_id
          )
        )
        expect(ApprovalRules::ExternalApprovalRulePayloadWorker).not_to receive(:perform_async)

        subject
      end
    end
  end

  describe 'failed?' do
    let_it_be(:rule, freeze: false) { create(:external_status_check) }
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }

    let(:project) { merge_request.source_project }

    subject { rule.failed?(merge_request) }

    context 'when last status check response is failed' do
      before do
        create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.diff_head_sha, status: 'passed')
        create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.diff_head_sha, status: 'failed')
      end

      it { is_expected.to be true }
    end

    context 'when last status check response is passed' do
      before do
        create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.diff_head_sha, status: 'failed')
        create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.diff_head_sha, status: 'passed')
      end

      it { is_expected.to be false }
    end

    context 'when there are no status check responses' do
      before do
        merge_request.status_check_responses.delete_all
      end

      it { is_expected.to be false }
    end
  end

  describe 'status' do
    let_it_be(:rule, freeze: false) { create(:external_status_check) }
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }

    let(:project) { merge_request.source_project }

    subject { rule.status(merge_request, merge_request.source_branch_sha) }

    context 'when a rule has a positive status check response' do
      let_it_be(:status_check_response, freeze: false) { create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.source_branch_sha, status: 'passed') }

      it { is_expected.to eq('passed') }

      context 'when a rule also has a positive check response from an old sha' do
        before do
          create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: 'abc1234', status: 'passed')
        end

        it { is_expected.to eq('passed') }
      end
    end

    context 'when a rule has a negative status check response' do
      let_it_be(:status_check_response, freeze: false) { create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.source_branch_sha, status: 'failed') }

      it { is_expected.to eq('failed') }
    end

    context 'when a rule has no status check response' do
      it { is_expected.to eq('pending') }
    end

    context 'when a rule has already been retried' do
      let_it_be(:status_check_response, freeze: false) { create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.source_branch_sha, status: 'failed', retried_at: Time.current) }

      it { is_expected.to eq('failed') }
    end
  end

  describe 'response_for' do
    let_it_be(:rule, freeze: false) { create(:external_status_check) }
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }
    let_it_be(:first_response, freeze: false) { create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.source_branch_sha) }
    let_it_be(:second_response, freeze: false) { create(:status_check_response, merge_request: merge_request, external_status_check: rule, sha: merge_request.source_branch_sha, status: 'failed') }

    let(:project) { merge_request.source_project }

    subject { rule.response_for(merge_request, merge_request.source_branch_sha) }

    before do
      first_response
      second_response
    end

    it { is_expected.to eq(second_response) }
  end

  describe 'hmac?' do
    let_it_be(:merge_request, freeze: false) { create(:merge_request) }
    let(:project) { merge_request.source_project }

    context 'when shared secret is saved' do
      let_it_be(:rule, freeze: false) { create(:external_status_check, shared_secret: 'shared_secret') }

      subject { rule.hmac? }

      it { is_expected.to be(true) }
    end

    context 'when shared secret is not saved' do
      let_it_be(:rule, freeze: false) { create(:external_status_check) }

      subject { rule.hmac? }

      it { is_expected.to be(false) }
    end

    context 'when shared secret had invalid value' do
      ['', ' ', nil].each do |value|
        context "with invalid value #{value}" do
          let_it_be(:rule, freeze: false) { create(:external_status_check, shared_secret: value) }

          subject { rule.hmac? }

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe 'callbacks', :request_store do
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be(:master_branch, freeze: false) { create(:protected_branch, project: project, name: 'master') }
    let_it_be(:main_branch, freeze: false) { create(:protected_branch, project: project, name: 'main') }
    let_it_be_with_reload(:external_status_check) do
      create(:external_status_check, project: project, name: 'QA', protected_branches: [])
    end

    describe '#audit_add branches after :add' do
      context 'when branch is added from zero branches' do
        let(:action!) { external_status_check.update!(protected_branches: [main_branch]) }
        let(:message) { 'Added protected branch main to QA status check and removed all other branches from status check' }

        it_behaves_like 'audit event queue'
      end

      context 'when another branch is added' do
        before do
          external_status_check.update!(protected_branches: [main_branch])
        end

        let(:action!) { external_status_check.update!(protected_branches: [main_branch, master_branch]) }
        let(:message) { 'Added protected branch master to QA status check' }

        it_behaves_like 'audit event queue'
      end
    end

    describe '#audit_remove branches after :remove' do
      context 'when all the branches are removed' do
        before do
          external_status_check.update!(protected_branches: [main_branch])
        end

        let(:action!) { external_status_check.update!(protected_branches: []) }
        let(:message) { 'Added all branches to QA status check' }

        it_behaves_like 'audit event queue'
      end

      context 'when a branch is removed' do
        before do
          external_status_check.update!(protected_branches: [main_branch, master_branch])
        end

        let(:action!) { external_status_check.update!(protected_branches: [master_branch]) }
        let(:message) { 'Removed protected branch main from QA status check' }

        it_behaves_like 'audit event queue'
      end
    end

    describe '#audit_creation external status check after :create' do
      context 'when protected branches are added' do
        let_it_be(:external_status_check, freeze: false) do
          described_class.new(
            name: 'QAv2',
            project: project,
            external_url: 'https://www.example.com',
            protected_branch_ids: [main_branch.id, master_branch.id]
          )
        end

        let(:action!) { external_status_check.save! }
        let(:message) { 'Added QAv2 status check with protected branch(es) main, master' }

        it_behaves_like 'audit event queue'
      end

      context 'when all branches are added' do
        let_it_be(:external_status_check, freeze: false) do
          described_class.new(
            name: 'QAv2',
            project: project,
            external_url: 'https://www.example.com',
            protected_branch_ids: []
          )
        end

        let(:action!) { external_status_check.save! }
        let(:message) { 'Added QAv2 status check with all branches' }

        it_behaves_like 'audit event queue'
      end
    end

    describe '#audit_creation external status check after :create' do
      let(:action!) { external_status_check.destroy! }
      let(:message) { 'Removed QA status check' }

      it_behaves_like 'audit event queue'
    end
  end
end
