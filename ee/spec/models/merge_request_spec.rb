# frozen_string_literal: true

require 'spec_helper'

# Store feature-specific specs in `ee/spec/models/merge_request instead of
# making this file longer.
#
# For instance, `ee/spec/models/merge_request/blocking_spec.rb` tests the
# "blocking MRs" feature.
RSpec.describe MergeRequest, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax
  include ReactiveCachingHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }

  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  shared_context 'with a merge request' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project)
    end
  end

  shared_context 'with a security orchestration policy configuration' do
    let_it_be(:security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project,
        security_policy_management_project: project)
    end
  end

  describe 'associations' do
    subject { build_stubbed(:merge_request) }

    it { is_expected.to have_many(:approvals).dependent(:delete_all) }
    it { is_expected.to have_many(:approved_by_users) }
    it { is_expected.to have_one(:merge_train_car) }
    it { is_expected.to have_many(:approval_rules) }
    it { is_expected.to have_many(:approval_policy_merge_request_bypass_events) }
    it { is_expected.to have_many(:approval_merge_request_rule_sources).through(:approval_rules) }
    it { is_expected.to have_many(:approval_project_rules).through(:approval_merge_request_rule_sources) }

    it do
      is_expected
        .to(
          have_many(:status_check_responses)
            .class_name('MergeRequests::StatusCheckResponse')
            .inverse_of(:merge_request)
        )
    end

    it 'has many `duo_workflow_links`' do
      is_expected.to have_many(:duo_workflow_links)
        .class_name('Ai::DuoWorkflows::WorkflowMergeRequest').with_foreign_key(:merge_request_id)
        .inverse_of(:merge_request)
    end

    it { is_expected.to have_many(:linked_duo_workflows).through(:duo_workflow_links).source(:workflow) }

    it do
      is_expected
        .to(
          have_many(:scan_result_policy_reads_through_violations)
            .through(:scan_result_policy_violations)
            .class_name('Security::ScanResultPolicyRead')
        )
    end

    it do
      is_expected
        .to(
          have_many(:scan_result_policy_reads_through_approval_rules)
            .through(:approval_rules)
            .class_name('Security::ScanResultPolicyRead')
        )
    end

    it do
      is_expected
        .to(
          have_many(:security_policies_through_violations)
            .through(:scan_result_policy_violations)
            .class_name('Security::Policy')
        )
    end

    it { is_expected.to have_many(:change_requesters).through(:requested_changes) }
    it { is_expected.to have_many(:policy_dismissals) }

    describe 'policy violations' do
      include_context 'with a security orchestration policy configuration'

      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      let_it_be(:policy_1) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:policy_2) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:policy_3) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:policy_4) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:running_violation_1) do
        create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_1, violation_data: nil)
      end

      let_it_be(:running_violation_2) do
        create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_2, violation_data: nil)
      end

      let_it_be(:failed_violation_1) do
        create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_3, violation_data: nil)
      end

      let_it_be(:failed_violation_2) do
        create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_4, violation_data: nil)
      end

      describe '.running_scan_result_policy_violations' do
        it 'returns only the running violations' do
          expect(merge_request.running_scan_result_policy_violations).to contain_exactly(running_violation_1,
            running_violation_2)
        end
      end

      describe '.failed_scan_result_policy_violations' do
        it 'returns only the completed violations' do
          expect(merge_request.failed_scan_result_policy_violations).to contain_exactly(failed_violation_1,
            failed_violation_2)
        end
      end
    end

    describe 'approval_rules association' do
      include_context 'with a merge request'

      describe 'applicable_post_merge_approval_rules' do
        it 'returns only the rules applicable_post_merge true or nil' do
          create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: false)
          rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)
          rule_3 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)

          expect(merge_request.applicable_post_merge_approval_rules).to contain_exactly(rule_2, rule_3)
        end
      end

      describe '#applicable_to_branch' do
        let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
        let(:branch) { 'stable' }

        subject { merge_request.approval_rules.applicable_to_branch(branch) }

        shared_examples_for 'with applicable rules to specified branch' do
          it { is_expected.to eq([rule]) }
        end

        context 'when there are no associated source rules' do
          it_behaves_like 'with applicable rules to specified branch'
        end

        context 'when there are associated source rules' do
          let!(:source_rule) { create(:approval_project_rule, project: merge_request.target_project) }
          let!(:rule) do
            create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: source_rule)
          end

          context 'and rule is not modified_from_project_rule' do
            before do
              rule.update!(
                name: source_rule.name,
                approvals_required: source_rule.approvals_required,
                users: source_rule.users,
                groups: source_rule.groups
              )
            end

            context 'and there are no associated protected branches to source rule' do
              it_behaves_like 'with applicable rules to specified branch'
            end

            context 'and there are associated protected branches to source rule' do
              before do
                source_rule.update!(protected_branches: protected_branches)
              end

              context 'and branch matches' do
                let(:protected_branches) { [create(:protected_branch, project: project, name: branch)] }

                it_behaves_like 'with applicable rules to specified branch'
              end

              context 'and branch does not match anything' do
                let(:protected_branches) { [create(:protected_branch, project: project, name: branch.reverse)] }

                it { is_expected.to be_empty }
              end
            end
          end

          context 'and rule is modified_from_project_rule' do
            before do
              rule.update!(name: 'Overridden Rule')
            end

            it_behaves_like 'with applicable rules to specified branch'
          end

          context 'and rule is overridden but not modified_from_project_rule' do
            let!(:rule) do
              create(:approval_merge_request_rule, name: 'test', merge_request: merge_request,
                approval_project_rule: source_rule)
            end

            it_behaves_like 'with applicable rules to specified branch'

            context 'and protected branches exist but branch does not match anything' do
              let(:protected_branches) { [create(:protected_branch, project: project, name: branch.reverse)] }

              before do
                source_rule.update!(protected_branches: protected_branches)
              end

              it 'does not find applicable rules' do
                expect(subject).to be_empty
              end
            end
          end
        end
      end

      describe '#set_applicable_when_copying_rules' do
        let!(:rule_2) { create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil) }
        let!(:rule_1) { create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil) }
        let(:ids) { [rule_2.id] }

        subject { merge_request.approval_rules.set_applicable_when_copying_rules(ids) }

        it 'sets all the ids to true and others to false' do
          pre_set = merge_request.approval_rules.all? { |rule| rule.applicable_post_merge.nil? }
          expect(pre_set).to be(true)

          subject

          expect(rule_1.reload.applicable_post_merge).to be(false)
          expect(rule_2.reload.applicable_post_merge).to be(true)
        end
      end
    end

    describe '#merge_requests_author_approval?' do
      context 'when project lacks a target_project relation' do
        before do
          merge_request.target_project = nil
        end

        it 'returns false' do
          expect(merge_request.merge_requests_author_approval?).to be false
        end
      end

      context 'when project has a target_project relation' do
        it 'accesses the value from the target_project' do
          expect(merge_request.target_project)
            .to receive(:merge_requests_author_approval?)

          merge_request.merge_requests_author_approval?
        end

        context 'when overridden by scan result policy' do
          include_context 'with a merge request'
          include_context 'with a security orchestration policy configuration'

          let_it_be(:security_policy) do
            create(:security_policy, :with_approval_settings,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be_with_reload(:approval_policy_rule) do
            create(:approval_policy_rule, security_policy: security_policy)
          end

          let_it_be(:policy) do
            create(
              :scan_result_policy_read,
              :prevent_approval_by_author,
              commits: :any,
              project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration,
              approval_policy_rule: approval_policy_rule)
          end

          before_all do
            merge_request.target_project.update_attribute(:merge_requests_author_approval, true)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy,
              approval_policy_rule: approval_policy_rule)
          end

          it 'returns false' do
            expect(merge_request.merge_requests_author_approval?).to be(false)
          end

          context 'with warn mode' do
            before do
              approval_policy_rule.update!(security_policy: create(:security_policy, :enforcement_type_warn,
                policy_index: 1,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration))
            end

            it 'returns true' do
              expect(merge_request.merge_requests_author_approval?).to be(true)
            end
          end
        end
      end
    end

    describe '#merge_requests_disable_committers_approval?' do
      context 'when project lacks a target_project relation' do
        before do
          merge_request.target_project = nil
        end

        it 'returns false' do
          expect(merge_request.merge_requests_disable_committers_approval?).to be false
        end
      end

      context 'when project has a target_project relation' do
        it 'accesses the value from the target_project' do
          expect(merge_request.target_project)
            .to receive(:merge_requests_disable_committers_approval?)

          merge_request.merge_requests_disable_committers_approval?
        end

        context 'when overridden by scan result policy' do
          include_context 'with a merge request'
          include_context 'with a security orchestration policy configuration'

          let_it_be(:security_policy) do
            create(:security_policy, content: { approval_settings: { prevent_approval_by_commit_author: true } },
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be_with_reload(:approval_policy_rule) do
            create(:approval_policy_rule, security_policy: security_policy)
          end

          let_it_be(:policy) do
            create(
              :scan_result_policy_read,
              :prevent_approval_by_commit_author,
              commits: :any,
              project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration,
              approval_policy_rule: approval_policy_rule)
          end

          before_all do
            merge_request.target_project.update_attribute(:merge_requests_disable_committers_approval, false)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy,
              approval_policy_rule: approval_policy_rule)
          end

          it 'returns false' do
            expect(merge_request.merge_requests_disable_committers_approval?).to be(true)
          end

          context 'with warn mode' do
            before do
              approval_policy_rule.update!(security_policy: create(:security_policy, :enforcement_type_warn,
                policy_index: 1,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration))
            end

            it 'returns false' do
              expect(merge_request.merge_requests_disable_committers_approval?).to be(false)
            end
          end
        end
      end
    end

    describe '#require_password_to_approve?' do
      subject { merge_request.require_password_to_approve? }

      let(:password_required?) { true }

      include_context 'with a security orchestration policy configuration'

      before do
        merge_request.target_project.update!(require_password_to_approve: password_required?)
      end

      context 'when target project requires password' do
        it { is_expected.to be(password_required?) }
      end

      context 'when target project does not require password' do
        let(:password_required?) { false }

        it { is_expected.to be(password_required?) }

        context 'when overridden by scan result policy' do
          include_context 'with a merge request'

          let_it_be(:security_policy) do
            create(:security_policy, content: { approval_settings: { require_password_to_approve: true } },
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let_it_be_with_reload(:approval_policy_rule) do
            create(:approval_policy_rule, security_policy: security_policy)
          end

          let_it_be(:policy) do
            create(
              :scan_result_policy_read,
              :require_password_to_approve,
              commits: :any,
              project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration,
              approval_policy_rule: approval_policy_rule)
          end

          before_all do
            merge_request.target_project.update_attribute(:merge_requests_disable_committers_approval, false)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy,
              approval_policy_rule: approval_policy_rule)
          end

          it { is_expected.to be(true) }

          context 'with warn mode' do
            before do
              approval_policy_rule.update!(security_policy: create(:security_policy, :enforcement_type_warn,
                policy_index: 1,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration))
            end

            it { is_expected.to be(false) }
          end
        end
      end

      describe '#policy_approval_settings' do
        include_context 'with a merge request'

        let_it_be(:project_approval_settings) do
          { prevent_approval_by_author: true,
            prevent_approval_by_commit_author: false,
            remove_approvals_with_new_commit: true,
            require_password_to_approve: false }
        end

        let_it_be(:security_policy) do
          create(:security_policy, content: { approval_settings: project_approval_settings },
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be_with_reload(:approval_policy_rule) do
          create(:approval_policy_rule, security_policy: security_policy)
        end

        let_it_be(:policy) do
          create(:scan_result_policy_read,
            project: merge_request.target_project,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration,
            project_approval_settings: project_approval_settings,
            approval_policy_rule: approval_policy_rule)
        end

        let(:overrides) { project_approval_settings.select { |_, v| v } }

        subject(:approval_settings) { merge_request.policy_approval_settings }

        context 'with scan finding rule' do
          let!(:approval_merge_request_rule) do
            build_stubbed(:report_approver_rule,
              :scan_finding,
              merge_request: merge_request,
              scan_result_policy_read: policy)
          end

          context 'when violated' do
            before do
              create(:scan_result_policy_violation, project: project, merge_request: merge_request,
                scan_result_policy_read: approval_merge_request_rule.scan_result_policy_read,
                approval_policy_rule: approval_policy_rule)
            end

            it { is_expected.to eq(overrides) }

            context 'when scan_result_policy_violations is already loaded' do
              before do
                merge_request.scan_result_policy_violations.load
              end

              it { is_expected.to eq(overrides) }
            end

            context 'with warn mode' do
              before do
                approval_policy_rule.update!(security_policy: create(:security_policy, :enforcement_type_warn,
                  policy_index: 1,
                  security_orchestration_policy_configuration: security_orchestration_policy_configuration))
              end

              it { is_expected.to be_empty }

              context 'when deprecate_scan_result_policies is disabled' do
                before do
                  stub_feature_flags(deprecate_scan_result_policies: false)
                end

                it { is_expected.to be_empty }
              end
            end

            context 'when deprecate_scan_result_policies is disabled' do
              before do
                stub_feature_flags(deprecate_scan_result_policies: false)
              end

              it { is_expected.to eq(overrides) }
            end
          end

          context 'when violation has no scan_result_policy_read' do
            before do
              create(:scan_result_policy_violation, project: project, merge_request: merge_request,
                scan_result_policy_read: nil, approval_policy_rule: approval_policy_rule)
            end

            it { is_expected.to eq(overrides) }
          end

          context 'when unviolated' do
            it { is_expected.to be_empty }
          end
        end

        context 'with any_merge_request rule' do
          let!(:approval_merge_request_rule) do
            build_stubbed(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy,
              approvals_required: 1)
          end

          context 'when violated' do
            before do
              create(
                :scan_result_policy_violation,
                project: project,
                merge_request: merge_request,
                scan_result_policy_read: approval_merge_request_rule.scan_result_policy_read,
                approval_policy_rule: approval_policy_rule)
            end

            it { is_expected.to eq(overrides) }
          end

          context 'when unviolated' do
            it { is_expected.to be_empty }
          end

          context 'when rule is violated by other merge request' do
            let(:merge_request_2) do
              create(:merge_request, source_branch: 'test', source_project: project, target_project: project,
                state: :opened)
            end

            let(:project_approval_settings_2) do
              { prevent_approval_by_author: true,
                prevent_approval_by_commit_author: true,
                remove_approvals_with_new_commit: true,
                require_password_to_approve: true }
            end

            let(:security_policy_2) do
              create(:security_policy, content: { approval_settings: project_approval_settings_2 },
                policy_index: 1,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            let(:approval_policy_rule_2) do
              create(:approval_policy_rule, security_policy: security_policy_2)
            end

            let(:policy_2) do
              create(:scan_result_policy_read, project: project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration,
                project_approval_settings: project_approval_settings_2, approval_policy_rule: approval_policy_rule_2)
            end

            before do
              create(:scan_result_policy_violation, project: project, merge_request: merge_request,
                scan_result_policy_read: policy, approval_policy_rule: approval_policy_rule)

              create(:scan_result_policy_violation, project: project, merge_request: merge_request_2,
                scan_result_policy_read: policy_2, approval_policy_rule: approval_policy_rule_2)
            end

            it 'applies violations for the correct merge request' do
              is_expected.to eq(overrides)
            end
          end

          context 'with competing rules' do
            let(:other_security_policy) do
              create(:security_policy,
                content: { approval_settings: project_approval_settings.transform_values { false } },
                policy_index: 1,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration)
            end

            let(:other_approval_policy_rule) do
              create(:approval_policy_rule, security_policy: other_security_policy)
            end

            let(:other_policy) do
              create(
                :scan_result_policy_read,
                project: merge_request.target_project,
                security_orchestration_policy_configuration: security_orchestration_policy_configuration,
                project_approval_settings: project_approval_settings.transform_values { false },
                commits: :any,
                approval_policy_rule: other_approval_policy_rule)
            end

            let!(:other_approval_merge_request_rule) do
              build_stubbed(
                :approval_merge_request_rule,
                :any_merge_request,
                merge_request: merge_request,
                scan_result_policy_read: other_policy,
                approvals_required: 1)
            end

            before do
              [approval_merge_request_rule, other_approval_merge_request_rule].each do |rule|
                create(
                  :scan_result_policy_violation,
                  project: project,
                  merge_request: merge_request,
                  scan_result_policy_read: rule.scan_result_policy_read,
                  approval_policy_rule: rule.scan_result_policy_read.approval_policy_rule)
              end
            end

            it { is_expected.to eq(overrides) }
          end
        end
      end
    end
  end

  describe '#policies_overriding_approval_settings' do
    let_it_be(:project_approval_settings) do
      { prevent_approval_by_author: true,
        prevent_approval_by_commit_author: false,
        remove_approvals_with_new_commit: true,
        require_password_to_approve: false }
    end

    let_it_be_with_refind(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    let(:overrides) { project_approval_settings.compact_blank }

    include_context 'with a security orchestration policy configuration'

    subject(:overriding_policies) { merge_request.policies_overriding_approval_settings }

    context 'with security policies populated' do
      let(:policy) do
        create(:security_policy, content: { approval_settings: project_approval_settings },
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let(:policy_rule) do
        create(:approval_policy_rule, :any_merge_request, security_policy: policy)
      end

      context 'when violated' do
        before do
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: nil, approval_policy_rule: policy_rule)
        end

        it 'returns policies as keys and overrides as values', :aggregate_failures do
          expect(overriding_policies.keys).to contain_exactly(policy)
          expect(overriding_policies.values).to contain_exactly(overrides)
        end

        context 'when policy does not set approval_settings' do
          let(:policy) do
            create(:security_policy,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          it { is_expected.to be_empty }
        end

        context 'when policy does not set overriding approval_settings' do
          let(:policy) do
            create(:security_policy, content: { approval_settings: { require_password_to_approve: false } },
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          it { is_expected.to be_empty }
        end

        context 'when policy is in warn mode' do
          let(:policy) do
            create(:security_policy,
              content: { enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN,
                         approval_settings: { require_password_to_approve: true } },
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          it { is_expected.to be_empty }
        end

        context 'when there are multiple policies' do
          let(:other_approval_settings) { { require_password_to_approve: true } }
          let(:other_policy) do
            create(:security_policy, content: { approval_settings: other_approval_settings }, policy_index: 1,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          let(:other_policy_rule) do
            create(:approval_policy_rule, :any_merge_request, security_policy: other_policy)
          end

          let_it_be(:other_scan_result_policy_read) do
            create(:scan_result_policy_read, project: project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration)
          end

          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: other_scan_result_policy_read,
              approval_policy_rule: other_policy_rule)
          end

          it 'returns results and project overrides by policy', :aggregate_failures do
            expect(overriding_policies.keys).to contain_exactly(policy, other_policy)
            expect(overriding_policies.values).to contain_exactly(overrides, other_approval_settings)
          end

          context 'when other policies do not override approval settings' do
            let(:other_approval_settings) { { require_password_to_approve: false } }

            it 'only returns policies that override settings' do
              expect(overriding_policies.keys).to contain_exactly(policy)
            end
          end
        end
      end

      context 'when not violated' do
        it { is_expected.to be_empty }
      end
    end

    context 'when approval_policy_rule is not populated' do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          project_approval_settings: project_approval_settings)
      end

      context 'when violated' do
        before do
          create(:scan_result_policy_violation, project: project, merge_request: merge_request,
            scan_result_policy_read: scan_result_policy_read)
        end

        it 'constructs policy object as key and has overrides as values', :aggregate_failures do
          first_policy = overriding_policies.each_key.first
          expected_configuration_id = scan_result_policy_read.security_orchestration_policy_configuration_id
          expect(first_policy).to be_a(Security::Policy)
          expect(first_policy)
            .to have_attributes(
              name: nil,
              security_orchestration_policy_configuration_id: expected_configuration_id,
              policy_index: scan_result_policy_read.orchestration_policy_idx
            )
          expect(overriding_policies.values).to contain_exactly(overrides)
        end

        context 'when there are multiple policies' do
          let(:other_approval_settings) { { require_password_to_approve: true } }
          let!(:other_scan_result_policy_read) do
            create(:scan_result_policy_read,
              project: merge_request.target_project,
              security_orchestration_policy_configuration: security_orchestration_policy_configuration,
              orchestration_policy_idx: 1,
              project_approval_settings: other_approval_settings)
          end

          before do
            create(:scan_result_policy_violation, project: project, merge_request: merge_request,
              scan_result_policy_read: other_scan_result_policy_read)
          end

          it 'returns results and project overrides by policy', :aggregate_failures do
            expected_configuration_id = other_scan_result_policy_read.security_orchestration_policy_configuration_id
            expect(overriding_policies.keys.size).to eq(2)
            expect(overriding_policies.keys.last).to have_attributes(
              name: nil,
              security_orchestration_policy_configuration_id: expected_configuration_id,
              policy_index: other_scan_result_policy_read.orchestration_policy_idx
            )
            expect(overriding_policies.values).to contain_exactly(overrides, other_approval_settings)
          end

          context 'when other policies do not override approval settings' do
            let(:other_approval_settings) { { require_password_to_approve: false } }

            it 'only returns policies that override settings', :aggregate_failures do
              expect(overriding_policies.keys).to be_one
              expect(overriding_policies.values).to contain_exactly(overrides)
            end
          end
        end
      end

      context 'when not violated' do
        it { is_expected.to be_empty }
      end
    end
  end

  it_behaves_like 'an editable mentionable with EE-specific mentions' do
    subject { create(:merge_request, :simple) }

    let(:backref_text) { "merge request #{subject.to_reference}" }
    let(:set_mentionable_text) { ->(txt) { subject.description = txt } }
  end

  describe '#allow_external_status_checks?' do
    subject { merge_request.allow_external_status_checks? }

    let_it_be(:merge_request) { build_stubbed(:merge_request) }

    context 'when licensed feature `external_status_checks` is `false`' do
      before do
        stub_licensed_features(external_status_checks: false)
      end

      it { is_expected.to be false }
    end

    context 'when licensed feature `external_status_checks` is `true`' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      it { is_expected.to be true }
    end
  end

  describe '#can_resolve_with_ai?' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:user) { project.creator }
    let(:merge_request) { build_stubbed(:merge_request, source_project: project, target_project: project) }

    subject { merge_request.can_resolve_with_ai?(user) }

    before do
      stub_feature_flags(mr_ai_resolve_conflicts: project)
      merge_request.merge_status = :cannot_be_merged
    end

    it { is_expected.to be true }

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(mr_ai_resolve_conflicts: false)
      end

      it { is_expected.to be false }
    end

    context 'when the merge request can be merged' do
      before do
        merge_request.merge_status = :can_be_merged
      end

      it { is_expected.to be false }
    end

    context 'when the merge request is in cannot_be_merged_recheck state' do
      before do
        merge_request.merge_status = :cannot_be_merged_recheck
      end

      it { is_expected.to be true }
    end

    context 'when the merge request is in cannot_be_merged_rechecking state' do
      before do
        merge_request.merge_status = :cannot_be_merged_rechecking
      end

      it { is_expected.to be true }
    end

    context 'when user is nil' do
      subject { merge_request.can_resolve_with_ai?(nil) }

      it { is_expected.to be false }
    end

    context 'when the user cannot push code to the project' do
      let_it_be(:guest) { create(:user) }

      subject { merge_request.can_resolve_with_ai?(guest) }

      before_all do
        project.add_guest(guest)
      end

      it { is_expected.to be false }
    end

    context 'when the merge request comes from a fork' do
      include ProjectForksHelper

      # `fork_project` stubs a worker, so it cannot run in a `let_it_be` block.
      let(:forked_project) { fork_project(project) }

      let(:merge_request) do
        build_stubbed(:merge_request, source_project: forked_project, target_project: project)
      end

      it { is_expected.to be false }
    end

    context 'when the source branch is protected against the user' do
      let_it_be(:developer) { create(:user) }

      subject { merge_request.can_resolve_with_ai?(developer) }

      before_all do
        project.add_developer(developer)
        # 'master' is the source branch of the factory-built merge request below.
        create(:protected_branch, :maintainers_can_push, project: project, name: 'master')
      end

      it { is_expected.to be false }
    end
  end

  describe '#can_resolve_discussions_with_ai?' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:user) { project.creator }
    let(:merge_request) { build_stubbed(:merge_request, source_project: project, target_project: project) }

    subject { merge_request.can_resolve_discussions_with_ai?(user) }

    before do
      stub_feature_flags(resolve_discussion_with_duo: user)
    end

    it { is_expected.to be true }

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(resolve_discussion_with_duo: false)
      end

      it { is_expected.to be false }
    end

    context 'when user is nil' do
      subject { merge_request.can_resolve_discussions_with_ai?(nil) }

      it { is_expected.to be false }
    end

    context 'when the user cannot push code to the project' do
      let_it_be(:guest) { create(:user) }

      subject { merge_request.can_resolve_discussions_with_ai?(guest) }

      before_all do
        project.add_guest(guest)
      end

      it { is_expected.to be false }
    end
  end

  describe '#participants' do
    subject(:participants) { merge_request.participants }

    context 'with approval rule' do
      before do
        approver = create(:user)
        second_approver = create(:user)

        create(:approval_merge_request_rule, merge_request: merge_request, users: [approver, second_approver])
      end

      it 'returns only the author as a participant' do
        expect(participants).to contain_exactly(merge_request.author)
      end
    end
  end

  describe '#has_denied_policies?', feature_category: :software_composition_analysis do
    include_context 'with a security orchestration policy configuration'

    let_it_be(:shared_approval_policy_rule) do
      create(:approval_policy_rule,
        security_policy: create(:security_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration))
    end

    let(:merge_request) { create(:ee_merge_request, :with_license_scanning_reports, source_project: project) }

    let!(:head_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_license_scanning_feature_branch,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      allow_any_instance_of(Vulnerabilities::CompareSecurityReportsService)
        .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original
    end

    subject { merge_request.has_denied_policies? }

    context 'without existing pipeline' do
      it { is_expected.to be_falsey }
    end

    context 'with existing pipeline' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      context 'without license_scanning report' do
        let(:merge_request) { create(:ee_merge_request, :with_dependency_scanning_reports, source_project: project) }

        it { is_expected.to be_falsey }
      end

      context 'with license_scanning report' do
        context 'without denied policy' do
          it { is_expected.to be_falsey }
        end

        context 'with allowed policy' do
          let(:allowed_policy) do
            create(:software_license_policy, :allowed, :with_apache_license, project: project,
              approval_policy_rule: shared_approval_policy_rule)
          end

          before do
            allowed_policy
            synchronous_reactive_cache(merge_request)
          end

          it { is_expected.to be_falsey }
        end

        context 'with denied policy' do
          let_it_be(:denied_policy) do
            create(:software_license_policy, :denied, :with_apache_license, project: project,
              approval_policy_rule: shared_approval_policy_rule)
          end

          let_it_be(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }

          before do
            synchronous_reactive_cache(merge_request)

            create(:pm_package, name: "nokogiri", purl_type: "gem",
              other_licenses: [{ license_names: ["Apache-2.0"], versions: ["1.8.0"] }])
          end

          it { is_expected.to be_truthy }

          context 'with disabled licensed feature' do
            before do
              stub_licensed_features(license_scanning: false)
            end

            it { is_expected.to be_falsey }
          end

          context 'with License-Check enabled' do
            let_it_be(:license_check) do
              create(:report_approver_rule, :license_scanning, merge_request: merge_request)
            end

            context 'when rule is not approved' do
              before do
                allow_any_instance_of(ApprovalWrappedRule).to receive(:approved?).and_return(false)
              end

              it { is_expected.to be_truthy }
            end

            context 'when rule is approved' do
              before do
                allow_any_instance_of(ApprovalWrappedRule).to receive(:approved?).and_return(true)
              end

              it { is_expected.to be_falsey }
            end
          end
        end
      end
    end

    context 'without license_scanning report in base pipeline' do
      before do
        stub_licensed_features(license_scanning: true)
        synchronous_reactive_cache(merge_request)
      end

      let(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }

      context 'when the base pipeline is nil' do
        let!(:base_pipeline) { nil }

        it { is_expected.to be_falsey }
      end

      context 'when the base pipeline does not have license reports' do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#enabled_reports' do
    # rubocop:disable Layout/LineLength -- Table syntax
    where(:report_type, :with_reports, :feature, :artifact_report) do
      :sast                | [:with_sast_reports]                | :sast                | :sast_feature_branch
      :container_scanning  | [:with_container_scanning_reports]  | :container_scanning  | :container_scanning_feature_branch
      :dast                | [:with_dast_reports]                | :dast                | :dast_feature_branch
      :dependency_scanning | [:with_dependency_scanning_reports] | :dependency_scanning | :dependency_scanning_feature_branch
      :dependency_scanning | [:with_cyclonedx_reports]           | :dependency_scanning | :cyclonedx_with_matching_dependency_files
      :license_scanning    | [:with_cyclonedx_reports]           | :license_scanning    | :license_scanning_feature_branch
      :coverage_fuzzing    | [:with_coverage_fuzzing_reports]    | :coverage_fuzzing    | :coverage_fuzzing_report
      :secret_detection    | [:with_secret_detection_reports]    | :secret_detection    | :secret_detection_feature_branch
      :api_fuzzing         | [:with_api_fuzzing_reports]         | :api_fuzzing         | :api_fuzzing_report
    end
    # rubocop:enable Layout/LineLength

    with_them do
      subject { merge_request.enabled_reports[report_type] }

      before do
        stub_licensed_features({ feature => true })
      end

      context "when head pipeline has reports" do
        let(:merge_request) { create(:ee_merge_request, *with_reports, source_project: project) }

        it { is_expected.to be_truthy }
      end

      context "when head pipeline does not have reports" do
        let_it_be_with_refind(:merge_request) { create(:ee_merge_request, source_project: project) }

        it { is_expected.to be_falsy }

        context "but the child pipeline has reports" do
          let(:pipeline) do
            create(:ee_ci_pipeline, :success, project: project, sha: merge_request.diff_head_sha,
              merge_requests_as_head_pipeline: [merge_request])
          end

          let(:child_pipeline) { create(:ee_ci_pipeline, :success, project: project, child_of: pipeline) }
          let!(:child_build) { create(:ee_ci_build, artifact_report, pipeline: child_pipeline) }

          it 'returns true if report is supported for child pipelines' do
            supported_report_types_for_child_pipelines = [:sast, :secret_detection, :container_scanning]

            if supported_report_types_for_child_pipelines.include?(feature)
              is_expected.to be_truthy
            else
              is_expected.to be_falsy
            end
          end
        end
      end
    end
  end

  describe '#approvals_before_merge' do
    where(:license_value, :db_value, :expected) do
      true  | 5   | 5
      true  | nil | nil
      false | 5   | nil
      false | nil | nil
    end

    with_them do
      let(:merge_request) { build(:merge_request, approvals_before_merge: db_value) }

      subject { merge_request.approvals_before_merge }

      before do
        stub_licensed_features(merge_request_approvers: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#has_security_reports?' do
    subject { merge_request.has_security_reports? }

    before do
      stub_licensed_features(dast: true)
    end

    context 'when head pipeline has security reports' do
      let(:merge_request) { create(:ee_merge_request, :with_dast_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have security reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_metrics_reports?' do
    subject { merge_request.has_metrics_reports? }

    before do
      stub_licensed_features(metrics_reports: true)
    end

    context 'when head pipeline has metrics reports' do
      let(:merge_request) { create(:ee_merge_request, :with_metrics_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when the head pipeline is still in progress' do
        it 'does not return any metrics reports' do
          merge_request.head_pipeline.update!(status: 'running')

          expect(subject).to be_falsey
        end
      end
    end

    context 'when head pipeline does not have metrics reports' do
      let(:merge_request) { create(:ee_merge_request, :with_head_pipeline, source_project: project) }

      before do
        merge_request.head_pipeline.update!(status: 'success')
      end

      it { is_expected.to be_falsey }

      context 'when child pipeline has metrics reports' do
        it 'returns child report' do
          create(:ee_ci_pipeline, :success, :with_metrics_report, child_of: merge_request.head_pipeline)

          expect(subject).to be_truthy
        end
      end
    end
  end

  describe '#calculate_reactive_cache with current_user' do
    let(:current_user) { project.users.take }
    let(:merge_request) { create(:merge_request, source_project: project) }

    subject { merge_request.calculate_reactive_cache(service_class_name, current_user&.id) }

    context 'when given a known service class name' do
      let(:service_class_name) { 'Ci::CompareTestReportsService' }

      it 'does not raises a NameError exception' do
        allow_any_instance_of(service_class_name.constantize).to receive(:execute).and_return(nil)

        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#compare_license_scanning_reports', feature_category: :software_composition_analysis do
    subject { merge_request.compare_license_scanning_reports(current_user) }

    include_context 'with a merge request'

    let(:current_user) { project.users.first }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_cyclonedx_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has cyclonedx reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareLicenseScanningReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'cache key includes software license policies' do
          let!(:license_1) do
            create(:software_license_policy, :with_apache_license, project: project, approval_policy_rule: nil)
          end

          let!(:license_2) do
            create(:software_license_policy, :with_mit_license, project: project, approval_policy_rule: nil)
          end

          it 'returns key with license information' do
            expect_any_instance_of(Ci::CompareLicenseScanningReportsService)
              .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

            expect(subject[:key].last).to include("software_license_policies/query-")
            expect(subject[:data]['existing_licenses'].last.dig('classification',
              'approval_status')).to eq('unclassified')
          end
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareLicenseScanningReportsService)
              .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end

    context 'when head pipeline does not have cyclonedx reports' do
      let!(:head_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
        expect(subject[:status_reason]).to eq('This merge request does not have license scanning reports.')
      end
    end

    context "when a cyclonedx report is produced from the head pipeline" do
      where(:pipeline_status, :build_types, :expected_status) do
        [
          [:blocked, [:container_scanning], :error],
          [:blocked, [:cyclonedx], :parsed],
          [:blocked, [:cyclonedx, :container_scanning], :parsed],
          [:blocked, [], :error],
          [:failed, [:container_scanning], :error],
          [:failed, [:cyclonedx], :parsed],
          [:failed, [:cyclonedx, :container_scanning], :parsed],
          [:failed, [], :error],
          [:running, [:container_scanning], :error],
          [:running, [:cyclonedx], :error],
          [:running, [:cyclonedx, :container_scanning], :error],
          [:running, [], :error],
          [:success, [:container_scanning], :error],
          [:success, [:cyclonedx], :parsed],
          [:success, [:cyclonedx, :container_scanning], :parsed],
          [:success, [], :error]
        ]
      end

      with_them do
        let!(:head_pipeline) do
          create(:ci_pipeline, pipeline_status, project: project, ref: merge_request.source_branch,
            sha: merge_request.diff_head_sha)
        end

        let!(:builds) do
          build_types.map { |build_type| create(:ee_ci_build, build_type, pipeline: head_pipeline) }
        end

        before do
          synchronous_reactive_cache(merge_request)
        end

        specify { expect(subject[:status]).to eq(expected_status) }
      end
    end
  end

  describe '#compare_license_scanning_reports_collapsed', feature_category: :software_composition_analysis do
    subject(:report) { merge_request.compare_license_scanning_reports_collapsed(current_user) }

    include_context 'with a merge request'

    let(:current_user) { project.users.first }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_license_scanning_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    let!(:head_pipeline) do
      create(
        :ci_pipeline,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    context 'when service can be executed' do
      before do
        merge_request.update!(head_pipeline_id: head_pipeline.id)

        allow_next_instance_of(::Gitlab::LicenseScanning::SbomScanner) do |scanner|
          allow(scanner).to receive(:results_available?).and_return(true)
        end
      end

      it 'returns compared report' do
        expect(report[:status]).to eq(:parsing)
      end
    end

    context 'when head pipeline does not have license scanning reports' do
      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
      end
    end
  end

  describe '#compare_metrics_reports' do
    subject { merge_request.compare_metrics_reports }

    include_context 'with a merge request'

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_metrics_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has metrics reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_metrics_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareMetricsReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareMetricsReportsService)
              .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end

    context 'when head pipeline does not have metrics reports' do
      let!(:head_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
        expect(subject[:status_reason]).to eq('This merge request does not have metrics reports.')
      end
    end
  end

  describe '#predefined_variables' do
    include_context 'with a merge request'

    context 'when merge request has approver feature' do
      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      context 'without any rules' do
        it 'includes variable CI_MERGE_REQUEST_APPROVED=true' do
          expect(merge_request.predefined_variables.to_hash).to include('CI_MERGE_REQUEST_APPROVED' => 'true')
        end

        context 'when the mr is temporarily unapproved' do
          it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
            expect(merge_request.approval_state).to receive(:temporarily_unapproved?).and_return(true)

            expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
          end
        end
      end

      context 'with a rule' do
        let(:approver) { create(:user) }
        let!(:rule) do
          create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 1, users: [approver])
        end

        context 'that has been approved' do
          it 'includes variable CI_MERGE_REQUEST_APPROVED=true' do
            create(:approval, merge_request: merge_request, user: approver)

            expect(merge_request.predefined_variables.to_hash).to include('CI_MERGE_REQUEST_APPROVED' => 'true')
          end
        end

        context 'that has not been approved' do
          it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
            expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
          end
        end
      end
    end

    context 'when merge request does not have approver feature' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
        expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
      end
    end
  end

  describe '#mergeable?' do
    context 'with skip_approved_check option' do
      before do
        allow(subject).to receive_messages(mergeable_ci_state?: true,
          mergeable_discussions_state?: true,
          check_mergeability: nil,
          can_be_merged?: true,
          broken?: false)
      end

      where(:approved_state, :skip_approved_check, :expected_mergeable) do
        false | false | false
        false | true  | true
        true  | false | true
        true  | true  | true
      end

      with_them do
        it 'overrides mergeable?' do
          allow(merge_request).to receive(:approved?) { approved_state }

          expect(merge_request.mergeable?(skip_approved_check: skip_approved_check)).to eq(expected_mergeable)
        end
      end
    end
  end

  describe '#skipped_auto_merge_checks' do
    subject { merge_request.skipped_auto_merge_checks(options) }

    let_it_be(:ee_checks) do
      %i[skip_approved_check skip_draft_check skip_blocked_check skip_discussions_check skip_external_status_check
        skip_locked_paths_check]
    end

    let(:merge_request) { build_stubbed(:merge_request) }
    let(:options) { { auto_merge_strategy: auto_merge_strategy } }

    context 'when auto_merge_strategy is blank' do
      let(:auto_merge_strategy) { '' }

      it 'does not skip any checks, including EE checks' do
        expect(subject.keys).to include(*ee_checks)
        expect(subject.values).to all(be_falsey)
      end
    end

    context 'when auto_merge_strategy is STRATEGY_MERGE_WHEN_CHECKS_PASS' do
      let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS }

      it 'skips all the checks except skip_rebase_check and skip_conflict_check' do
        expect(subject.keys).to include(*ee_checks)
        expect(subject.except(:skip_rebase_check, :skip_conflict_check).values).to all(be_truthy)
        expect(subject[:skip_rebase_check]).to be_falsy
      end
    end

    context 'when auto_merge_strategy is STRATEGY_MERGE_TRAIN' do
      let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_TRAIN }

      it 'skips only the rebase check by default' do
        expect(subject.except(:skip_rebase_check).values).to all(be_falsy)
        expect(subject[:skip_rebase_check]).to be_truthy
      end

      context 'when the diff head pipeline is a merge train pipeline' do
        before do
          allow(merge_request).to receive(:diff_head_pipeline).and_return(instance_double(Ci::Pipeline,
            merge_train_pipeline?: true))
        end

        context 'when the MR is on the train' do
          before do
            allow(merge_request).to receive(:on_train?).and_return(true)
          end

          it 'skips only the rebase check' do
            expect(subject.except(:skip_rebase_check).values).to all(be_falsy)
            expect(subject[:skip_rebase_check]).to be_truthy
          end
        end

        context 'when the MR is not on the train' do
          before do
            allow(merge_request).to receive(:on_train?).and_return(false)
          end

          context 'when pipeline is not being created' do
            before do
              allow(merge_request).to receive(:pipeline_creating?).and_return(false)
            end

            it 'skips the CI check and rebase check' do
              expect(subject).to include(skip_ci_check: true)
              expect(subject.except(:skip_ci_check, :skip_rebase_check).values).to all(be_falsy)
              expect(subject[:skip_rebase_check]).to be_truthy
            end
          end

          context 'when pipeline is being created' do
            before do
              allow(merge_request).to receive(:pipeline_creating?).and_return(true)
            end

            it 'skips only the rebase check' do
              expect(subject.except(:skip_rebase_check).values).to all(be_falsy)
              expect(subject[:skip_rebase_check]).to be_truthy
            end
          end
        end
      end
    end
  end

  describe '#mergeable_state?' do
    subject { merge_request.mergeable_state?(**params) }

    let(:params) { {} }
    let(:mr_project) { create(:project, :repository) }
    let(:merge_request) do
      create(:merge_request, source_project: mr_project, target_project: mr_project)
    end

    context 'when using approvals' do
      let(:user) { create(:user, developer_of: mr_project) }

      before do
        merge_request.target_project.update!(approvals_before_merge: 1)
      end

      context 'when not approved' do
        it 'is not mergeable' do
          is_expected.to be_falsey
        end
      end

      context 'when approved' do
        before do
          merge_request.approvals.create!(user: user)
        end

        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end

    context 'when validating jira associations' do
      let_it_be_with_reload(:project_jira) { create(:project, :repository, :with_jira_integration) }
      let_it_be_with_reload(:merge_request) do
        create(:merge_request, source_project: project_jira, target_project: project_jira)
      end

      before do
        allow(merge_request.project).to receive(:prevent_merge_without_jira_issue?).and_return(true)
      end

      context 'when the merge request does not reference a jira issue' do
        before do
          merge_request.update!(description: '')
        end

        it 'is not mergeable' do
          is_expected.to be_falsey
        end
      end

      context 'when the merge request references a jira issue' do
        before do
          merge_request.update!(description: 'PROJECT-1')
        end

        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end

    context 'when using external status checks' do
      let_it_be_with_refind(:mr_project) { create(:project, :repository) }
      let_it_be_with_refind(:merge_request) do
        create(:merge_request, source_project: mr_project, target_project: mr_project)
      end

      let(:any_external_status_checks_not_passed?) { false }

      before do
        allow(merge_request).to receive(:only_allow_merge_if_all_status_checks_passed_enabled?).and_return(true)
        allow(merge_request.project).to receive(:only_allow_merge_if_all_status_checks_passed).and_return(true)
        allow(merge_request.project).to receive(:any_external_status_checks_not_passed?)
                            .and_return(any_external_status_checks_not_passed?)
        stub_licensed_features(external_status_checks: true)
      end

      context 'when external checks pass' do
        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end

      context 'when external status checks are not passed' do
        let(:any_external_status_checks_not_passed?) { true }

        it 'is not mergeable' do
          is_expected.to be_falsey
        end

        context 'when skip external status checks is true' do
          let(:params) { { skip_external_status_check: true } }

          it 'is mergeable' do
            is_expected.to be_truthy
          end
        end
      end
    end

    context 'when blocking merge requests' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      context 'when the merge request is blocked' do
        let(:merge_request) { create(:merge_request, :blocked, source_project: project, target_project: project) }

        it 'is not mergeable' do
          is_expected.to be_falsey
        end

        context 'when skip blocked check' do
          let(:params) { { skip_blocked_check: true } }

          it 'is mergeable' do
            is_expected.to be_truthy
          end
        end
      end

      context 'when merge request is not blocked' do
        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end
  end

  describe '#on_train?' do
    subject { merge_request.on_train? }

    context 'when the merge request is on a merge train' do
      let(:merge_request) do
        create(:merge_request, :on_train, source_project: project, target_project: project)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the merge request was on a merge train' do
      let(:merge_request) do
        create(:merge_request, :on_train,
          status: MergeTrains::Car.state_machines[:status].states[:merged].value,
          source_project: project, target_project: project)
      end

      it { is_expected.to be_falsy }
    end

    context 'when the merge request is not on a merge train' do
      let(:merge_request) do
        create(:merge_request, source_project: project, target_project: project)
      end

      it { is_expected.to be_falsy }
    end
  end

  describe 'review time sorting' do
    def create_mr(metrics_data = {})
      create(:merge_request, :with_productivity_metrics, source_project: project, target_project: project,
        source_branch: "review-time-#{SecureRandom.hex(4)}", metrics_data: metrics_data)
    end

    it 'orders by first_comment_at or first_approved_at whatever is earlier' do
      mr1 = create_mr(first_comment_at: 1.day.ago)
      mr2 = create_mr(first_comment_at: 3.days.ago)
      mr3 = create_mr(first_approved_at: 5.days.ago)
      mr4 = create_mr(first_comment_at: 1.day.ago, first_approved_at: 4.days.ago)
      mr5 = create_mr(first_comment_at: nil, first_approved_at: nil)

      expect(described_class.order_review_time_desc).to match([mr3, mr4, mr2, mr1, mr5])
      expect(described_class.sort_by_attribute('review_time_desc')).to match([mr3, mr4, mr2, mr1, mr5])
    end
  end

  describe '#security_reports_up_to_date?' do
    let_it_be(:merge_request) do
      create(
        :ee_merge_request,
        source_project: project,
        source_branch: 'feature1',
        target_branch: project.default_branch
      )
    end

    before do
      create(
        :ee_ci_pipeline,
        :with_sast_report,
        project: project,
        ref: merge_request.target_branch
      )
    end

    subject { merge_request.security_reports_up_to_date? }

    context 'when the target branch security reports are up to date' do
      it { is_expected.to be true }
    end

    context 'when the target branch security reports are out of date' do
      before do
        create(:ee_ci_pipeline, :failed, project: project, ref: merge_request.target_branch)
      end

      it { is_expected.to be false }
    end
  end

  describe '#audit_details' do
    it 'equals to the title' do
      merge_request = build_stubbed(:merge_request, title: 'I am a title', source_project: project,
        target_project: project)

      expect(merge_request.audit_details).to eq(merge_request.title)
    end
  end

  describe '#validate_reviewer_length' do
    let(:reviewer1) { create(:user) }
    let(:reviewer2) { create(:user) }
    let(:reviewer3) { create(:user) }

    subject { create(:merge_request, source_project: project, target_project: project) }

    before do
      stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
    end

    it 'does not exceed the reviewer limit' do
      expect do
        subject.update!(reviewers: [reviewer1, reviewer2, reviewer3])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#synchronize_approval_rules_from_target_project' do
    let_it_be_with_reload(:merge_request) do
      create(:ee_merge_request, target_project: project, source_project: project)
    end

    let_it_be(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }

    let_it_be(:code_coverage_project_approval_rule) do
      create(:approval_project_rule, :code_coverage, project: project, approvals_required: 2)
    end

    let_it_be(:license_scanning_project_approval_rule) do
      create(:approval_project_rule, :license_scanning, project: project, approvals_required: 2)
    end

    let_it_be(:scan_finding_project_approval_rule) do
      create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2)
    end

    let_it_be(:any_merge_request_project_approval_rule) do
      create(:approval_project_rule, :any_merge_request, project: project, approvals_required: 2)
    end

    include_context 'with a security orchestration policy configuration'

    subject(:synchronize_approval_rules) { merge_request.synchronize_approval_rules_from_target_project }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    it 'resets security rules approvals but keeps code_coverage rule approvals' do
      synchronize_approval_rules

      expect(merge_request.approval_rules.map { |rule| [rule.report_type, rule.approvals_required] })
        .to match_array([['license_scanning', 0], ['code_coverage', 2], ['scan_finding', 0], ['any_merge_request', 0]])
    end

    context 'when the security orchestration policies feature not available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it 'does not create approval rules from scan result policies' do
        synchronize_approval_rules

        expect(merge_request.approval_rules.map { |rule| [rule.report_type, rule.approvals_required] })
          .to match_array([['code_coverage', 2]])
      end
    end

    context 'when syncing policy-linked approval rules' do
      let_it_be(:linked_policy_rule) do
        create(:approval_policy_rule, security_policy: create(:security_policy, policy_index: 0,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration))
      end

      let_it_be(:unlinked_policy_rule) do
        create(:approval_policy_rule, security_policy: create(:security_policy, policy_index: 1,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration))
      end

      let_it_be(:linked_project_rule) do
        create(:approval_project_rule, :scan_finding, project: project,
          approval_policy_rule: linked_policy_rule, approvals_required: 2,
          name: 'Linked rule')
      end

      let_it_be(:unlinked_project_rule) do
        create(:approval_project_rule, :scan_finding, project: project,
          approval_policy_rule: unlinked_policy_rule, approvals_required: 2,
          name: 'Unlinked rule')
      end

      before_all do
        create(:approval_policy_rule_project_link,
          approval_policy_rule: linked_policy_rule,
          project: project)
      end

      it 'only syncs rules with an active ApprovalPolicyRuleProjectLink' do
        synchronize_approval_rules

        synced_names = merge_request.approval_rules.pluck(:name)
        expect(synced_names).to include('Linked rule')
        expect(synced_names).not_to include('Unlinked rule')
      end

      it 'still syncs rules with nil approval_policy_rule_id' do
        synchronize_approval_rules

        synced_report_types = merge_request.approval_rules.pluck(:report_type)
        expect(synced_report_types).to include('code_coverage')
      end
    end

    context 'when multiple project rules share an approval_policy_rule' do
      let_it_be(:shared_policy_rule) do
        create(:approval_policy_rule, security_policy: create(:security_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration))
      end

      let_it_be(:scan_result_policy_read_1) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:scan_result_policy_read_2) do
        create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:shared_project_rule_1) do
        create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2,
          approval_policy_rule: shared_policy_rule, scan_result_policy_read: scan_result_policy_read_1)
      end

      let_it_be(:shared_project_rule_2) do
        create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2,
          approval_policy_rule: shared_policy_rule, scan_result_policy_read: scan_result_policy_read_2)
      end

      before do
        create(:approval_policy_rule_project_link, approval_policy_rule: shared_policy_rule, project: project)
      end

      it 'creates a single violation but still syncs both approval rules', :aggregate_failures do
        synchronize_approval_rules

        expect(merge_request.scan_result_policy_violations.where(approval_policy_rule_id: shared_policy_rule.id).count)
          .to eq(1)
        expect(merge_request.approval_rules.where(approval_policy_rule_id: shared_policy_rule.id).count).to eq(2)
      end
    end
  end

  describe '#sync_project_approval_rules_for_approval_policy_rules' do
    include_context 'with a security orchestration policy configuration'

    let_it_be(:merge_request) { create(:ee_merge_request, source_project: project) }
    let_it_be(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }

    let_it_be(:security_policy) do
      create(:security_policy, security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:project_approval_rule_without_policy_rule) { create(:approval_project_rule, project: project) }

    let_it_be(:project_approval_rule) do
      create(:approval_project_rule, :scan_finding,
        project: project,
        approval_policy_rule: approval_policy_rule,
        scanners: %w[sast],
        approvals_required: 2
      )
    end

    let_it_be(:approval_policy_rule_project_link) do
      create(:approval_policy_rule_project_link,
        project: project,
        approval_policy_rule: approval_policy_rule
      )
    end

    subject(:sync_project_approval_rules) do
      merge_request.sync_project_approval_rules_for_approval_policy_rules(security_policy.approval_policy_rules)
    end

    it 'creates approval rules for project and not for other configuration', :aggregate_failures do
      sync_project_approval_rules

      expect(merge_request.approval_rules.first.approval_project_rule).to eq(project_approval_rule)
      expect(merge_request.approval_rules.map(&:approval_project_rule))
        .not_to include(project_approval_rule_without_policy_rule)
    end

    context 'when mr approval rules already exist' do
      let_it_be(:mr_approval_rule) do
        create(:report_approver_rule, :scan_finding,
          merge_request: merge_request,
          approvals_required: 1
        )
      end

      let_it_be(:approval_rule_source) do
        create(:approval_merge_request_rule_source,
          approval_merge_request_rule: mr_approval_rule,
          approval_project_rule: project_approval_rule
        )
      end

      it 'updates approval rule' do
        subject

        expect(mr_approval_rule.reload.approvals_required).to eq(2)
      end
    end

    context 'when merge request is already merged' do
      let_it_be(:merge_request) { create(:ee_merge_request, source_project: project, state: :merged) }

      it 'does not create or update approval rule' do
        subject

        expect(merge_request.approval_rules).to be_empty
      end
    end
  end

  describe '#policy_bot_comment' do
    subject { merge_request.policy_bot_comment }

    let_it_be(:merge_request) { create(:ee_merge_request, source_project: project) }

    context 'without any comments' do
      it { is_expected.to be_nil }
    end

    context 'with a policy violation comment from the security bot' do
      include Security::PolicyBotCommentHelpers

      let!(:policy_bot_comment) { create_policy_bot_comment(merge_request) }

      it { is_expected.to eq policy_bot_comment }
    end

    context 'with another comment from the security bot' do
      before do
        create(
          :note,
          project: merge_request.project,
          noteable: merge_request,
          author: Users::Internal.in_organization(merge_request.project.organization).security_bot,
          note: 'Other note'
        )
      end

      it { is_expected.to be_nil }
    end
  end

  describe '.with_policy_bot_comment' do
    include Security::PolicyBotCommentHelpers

    let_it_be(:merge_request_with_comment) { create(:ee_merge_request, source_project: project) }
    let_it_be(:merge_request_without_comment) do
      create(:ee_merge_request, source_project: project, source_branch: 'feature-2')
    end

    before_all do
      create_policy_bot_comment(merge_request_with_comment)
    end

    subject(:scope) { described_class.with_policy_bot_comment(project) }

    it 'includes merge requests that have a policy bot comment' do
      expect(scope).to include(merge_request_with_comment)
    end

    it 'excludes merge requests without a policy bot comment' do
      expect(scope).not_to include(merge_request_without_comment)
    end
  end

  describe '#reset_required_approvals' do
    subject(:execute) { merge_request.reset_required_approvals(approval_rules) }

    include_context 'with a security orchestration policy configuration'

    let_it_be_with_reload(:merge_request) { create(:ee_merge_request, source_project: project) }
    let_it_be(:protected_branch) { create(:protected_branch, project: project, name: merge_request.target_branch) }
    let_it_be(:scan_finding_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, scanners: %w[sast], approvals_required: 2,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:license_project_rule) do
      create(:approval_project_rule, :license_scanning, :for_all_protected_branches,
        project: project, approvals_required: 2,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:other_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, scanners: %w[sast], approvals_required: 2,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    context 'when report_approver_rule has a project source' do
      let_it_be(:approval_rules) do
        [
          create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0,
            approval_project_rule: scan_finding_project_rule),
          create(:report_approver_rule, :license_scanning, merge_request: merge_request, approvals_required: 0,
            approval_project_rule: license_project_rule)
        ]
      end

      let_it_be(:other_approval_rule_with_project_source) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0,
          approval_project_rule: other_project_rule)
      end

      it 'resets the approvals_required for the provided approval_rules but not others' do
        expect { execute }.to change { approval_rules.first.reload.approvals_required }.from(0).to(2)
          .and change { approval_rules.second.reload.approvals_required }.from(0).to(2)
          .and not_change { other_approval_rule_with_project_source.reload.approvals_required }
      end

      context 'when merge request is already merged' do
        before do
          merge_request.update!(state: 'merged')
        end

        after do
          merge_request.update!(state: 'opened')
        end

        it 'does not update the approval rules' do
          expect { execute }.to not_change { approval_rules.first.reload.approvals_required }
            .and not_change { approval_rules.second.reload.approvals_required }
        end
      end
    end

    context "when report_approver_rule doesn't have a project source" do
      let_it_be(:approval_rules) do
        [create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0)]
      end

      it "doesn't reset the approval_rules" do
        expect { execute }.not_to change { approval_rules.first.reload }
      end
    end
  end

  context 'scopes' do
    let_it_be(:merge_request) { create(:ee_merge_request) }
    let_it_be(:merge_request_with_head_pipeline) { create(:ee_merge_request, :with_metrics_reports) }

    describe '.with_head_pipeline' do
      it 'returns MRs that have a head pipeline' do
        expect(described_class.with_head_pipeline).to eq([merge_request_with_head_pipeline])
      end
    end

    describe '.not_merged' do
      let(:opened_merge_request) { create(:merge_request, :opened) }
      let(:merged_merge_request) { create(:merge_request, :merged) }
      let(:closed_merge_request) { create(:merge_request, :closed) }
      let(:locked_merge_request) { create(:merge_request, :locked) }

      it 'returns everything except the merged mr' do
        expect(described_class.not_merged).to contain_exactly(merge_request, merge_request_with_head_pipeline,
          opened_merge_request, closed_merge_request, locked_merge_request)
      end
    end

    describe '.with_applied_scan_result_policies' do
      let_it_be(:code_coverage_approval_rule) do
        create(:report_approver_rule, :code_coverage,
          merge_request: create(:ee_merge_request, source_project: project, source_branch: 'cc',
            target_branch: 'master'))
      end

      let_it_be(:scan_finding_approval_rule) do
        create(:report_approver_rule, :scan_finding,
          merge_request: create(:ee_merge_request, source_project: project, source_branch: 'sf',
            target_branch: 'master'))
      end

      let_it_be(:license_scanning_approval_rule) do
        create(:report_approver_rule, :license_scanning,
          merge_request: create(:ee_merge_request, source_project: project, source_branch: 'ls',
            target_branch: 'master'))
      end

      let_it_be(:any_merge_request_approval_rule) do
        create(:report_approver_rule, :any_merge_request,
          merge_request: create(:ee_merge_request, source_project: project, source_branch: 'amr',
            target_branch: 'master'))
      end

      it 'returns MRs that have applied scan result policies' do
        expect(described_class.with_applied_scan_result_policies).to eq([
          scan_finding_approval_rule.merge_request,
          license_scanning_approval_rule.merge_request,
          any_merge_request_approval_rule.merge_request
        ])
      end
    end

    describe '.for_projects_with_security_policy_project' do
      include_context 'with a security orchestration policy configuration'

      let_it_be(:merge_request_with_security_policy_project) do
        create(:ee_merge_request, source_project: project)
      end

      let_it_be(:merge_request_without_security_policy_project) do
        create(:ee_merge_request, source_project: create(:project))
      end

      it 'returns MRs for projects with security policy project on target project' do
        expect(described_class.for_projects_with_security_policy_project).to eq(
          [merge_request_with_security_policy_project])
      end
    end

    describe '.with_approval_rules_by_report_types' do
      let_it_be(:scope_project) { create(:project) }
      let_it_be(:mr_with_scan_finding) do
        create(:merge_request, source_project: scope_project, source_branch: 'sf', target_branch: 'master')
      end

      let_it_be(:mr_with_license) do
        create(:merge_request, source_project: scope_project, source_branch: 'ls', target_branch: 'master')
      end

      let_it_be(:mr_without_rule) do
        create(:merge_request, source_project: scope_project, source_branch: 'none', target_branch: 'master')
      end

      before_all do
        create(:report_approver_rule, :scan_finding, merge_request: mr_with_scan_finding)
        create(:report_approver_rule, :license_scanning, merge_request: mr_with_license)
      end

      it 'returns only MRs carrying an approval rule of the given report types' do
        expect(scope_project.merge_requests.with_approval_rules_by_report_types([:scan_finding]))
          .to contain_exactly(mr_with_scan_finding)

        expect(scope_project.merge_requests.with_approval_rules_by_report_types([:scan_finding, :license_scanning]))
          .to contain_exactly(mr_with_scan_finding, mr_with_license)
      end

      it 'uses a correlated EXISTS rather than a materialised subquery' do
        sql = described_class.with_approval_rules_by_report_types([:scan_finding]).to_sql

        expect(sql).to include('EXISTS')
        expect(sql).to include(
          %("approval_merge_request_rules"."merge_request_id" = "merge_requests"."id")
        )
      end
    end
  end

  context 'after_commit hooks' do
    describe 'create_pending_status_check_responses' do
      subject(:create_merge_request) do
        create :merge_request, :opened, source_project: project, target_project: project
      end

      let(:merge_request) { described_class.last }

      context 'when project can have status checks' do
        before do
          stub_licensed_features(external_status_checks: true)
        end

        it 'creates `pending` status check responses' do
          expect(ComplianceManagement::PendingStatusCheckWorker).to receive(:perform_async).and_call_original

          create_merge_request
        end

        context 'when the the diff head SHA is empty' do
          it 'does not enqueue a status check' do
            expect(ComplianceManagement::PendingStatusCheckWorker).not_to receive(:perform_async)

            create :merge_request, :opened, source_project: project, target_project: project, source_branch: 'main',
              target_branch: 'foo'
          end
        end
      end

      context 'when project can not have status checks' do
        it 'does not create status check responses' do
          expect(ComplianceManagement::PendingStatusCheckWorker).not_to receive(:perform_async)

          create_merge_request
        end
      end
    end
  end

  context 'after_update hooks' do
    describe 'sync_merge_request_compliance_violation' do
      let_it_be_with_reload(:merge_request) do
        create(:merge_request, source_project: project, target_project: project, state: :merged, title: 'old MR title')
      end

      let_it_be(:compliance_violation) do
        create(:compliance_violation, :approved_by_committer, severity_level: :low, merge_request: merge_request,
          title: 'old MR title')
      end

      it "calls sync_merge_request_compliance_violation when the MR title is updated" do
        expect(merge_request.compliance_violations.pluck(:title)).to contain_exactly('old MR title')
        expect(merge_request).to receive(:sync_merge_request_compliance_violation).and_call_original

        merge_request.update_attribute(:title, "new MR title")

        expect(merge_request.compliance_violations.pluck(:title)).to contain_exactly('new MR title')
      end

      it "does not call sync_merge_request_compliance_violation when the MR title is not updated" do
        expect(merge_request).not_to receive(:sync_merge_request_compliance_violation)

        merge_request.update_attribute(:milestone, Milestone.last)
      end
    end
  end

  describe '#merge_train' do
    let(:merge_request) { build_stubbed(:merge_request, source_project: project, target_project: project) }

    subject { merge_request.merge_train }

    before do
      allow(project).to receive(:merge_trains_enabled?).and_return(setting)
    end

    context 'with MergeTrains disabled' do
      let(:setting) { false }

      it { is_expected.to be_nil }
    end

    context 'with MergeTrains enabled' do
      let(:setting) { true }

      it { is_expected.to be_a(MergeTrains::Train) }
    end
  end

  describe '#should_be_rebased?' do
    subject { merge_request.should_be_rebased? }

    shared_examples 'ff car on train' do
      context 'when MR is on an up-to-date fast-forward merge train' do
        before do
          car = create(:merge_train_car, merge_request: merge_request, target_project: project,
            pipeline: create(:ci_pipeline, project: project))

          merge_request.update!(
            merge_params: merge_request.merge_params.merge(
              'train_ref' => { 'commit_sha' => car.pipeline.sha }
            )
          )
        end

        it { is_expected.to be false }
      end
    end

    context 'when MR source branch needs to be rebased to be merged' do
      before do
        stub_foss_conditions_met
      end

      context 'when auto merge strategy is STRATEGY_MERGE_TRAIN' do
        before do
          merge_request.update!(auto_merge_enabled: true, merge_user: merge_request.author)
          merge_request.merge_params['auto_merge_strategy'] = AutoMergeService::STRATEGY_MERGE_TRAIN
        end

        it 'returns false because merge train handles rebasing' do
          is_expected.to be false
        end
      end

      context 'when auto merge strategy is STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS' do
        before do
          merge_request.update!(auto_merge_enabled: true, merge_user: merge_request.author)
          merge_request.merge_params['auto_merge_strategy'] =
            AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS
        end

        it 'returns false because merge train handles rebasing' do
          is_expected.to be false
        end
      end

      context 'when auto merge is not enabled' do
        it 'returns true when rebase is needed' do
          is_expected.to be true
        end

        it_behaves_like 'ff car on train'
      end

      context 'when auto merge strategy is not a merge train strategy' do
        before do
          merge_request.update!(auto_merge_enabled: true, merge_user: merge_request.author)
          merge_request.merge_params['auto_merge_strategy'] = AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS
        end

        it 'returns true when rebase is needed' do
          is_expected.to be true
        end
      end
    end

    def stub_foss_conditions_met
      allow(project).to receive(:ff_merge_must_be_possible?).and_return(true)
      allow(merge_request).to receive(:ff_merge_possible?).and_return(false)
    end
  end

  describe '#comparison_base_pipeline' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be(:base_pipeline) do
      create(:ci_pipeline,
        :with_test_reports,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    subject(:pipeline) { merge_request.comparison_base_pipeline(service_class) }

    context 'when the service class is `Vulnerabilities::CompareSecurityReportsService`' do
      let(:service_class) { ::Vulnerabilities::CompareSecurityReportsService }

      before do
        merge_request.update_head_pipeline
      end

      context 'when there are merge base pipelines' do
        let_it_be(:old_merge_base_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.target_branch_sha
          )
        end

        let_it_be(:most_recent_merge_base_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.target_branch_sha
          )
        end

        context 'when all pipelines have security reports' do
          before do
            build_1 = build(:ci_build,
              :sast_report,
              pipeline: old_merge_base_pipeline,
              project: project)

            build_2 = build(:ci_build,
              :sast_report,
              pipeline: most_recent_merge_base_pipeline,
              project: project)

            old_merge_base_pipeline.builds << build_1
            most_recent_merge_base_pipeline.builds << build_2
          end

          it 'returns the most recent merge base pipeline' do
            expect(pipeline).to eq(most_recent_merge_base_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            build = build(:ci_build,
              :sast_report,
              pipeline: old_merge_base_pipeline,
              project: project)

            old_merge_base_pipeline.builds << build
          end

          it 'returns the latest merge base pipeline with security reports' do
            expect(pipeline).to eq(old_merge_base_pipeline)
          end
        end
      end

      context 'when there is no merge base pipeline' do
        let_it_be(:old_base_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        let_it_be(:most_recent_base_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        context 'when all pipelines have security reports' do
          before do
            build_1 = build(:ci_build,
              :sast_report,
              pipeline: old_base_pipeline,
              project: project)

            build_2 = build(:ci_build,
              :sast_report,
              pipeline: most_recent_base_pipeline,
              project: project)

            old_base_pipeline.builds << build_1
            most_recent_base_pipeline.builds << build_2
          end

          it 'returns the most recent base pipeline' do
            expect(pipeline).to eq(most_recent_base_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            build = build(:ci_build,
              :sast_report,
              pipeline: old_base_pipeline,
              project: project)

            old_base_pipeline.builds << build
          end

          it 'returns the latest base pipeline with security reports' do
            expect(pipeline).to eq(old_base_pipeline)
          end
        end
      end

      context 'when there is no base pipeline' do
        let_it_be(:old_start_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_start_sha
          )
        end

        let_it_be(:most_recent_start_pipeline) do
          create(:ci_pipeline,
            :success,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_start_sha
          )
        end

        context 'when all pipelines have security reports' do
          before do
            build_1 = build(:ci_build,
              :sast_report,
              pipeline: old_start_pipeline,
              project: project)

            build_2 = build(:ci_build,
              :sast_report,
              pipeline: most_recent_start_pipeline,
              project: project)

            old_start_pipeline.builds << build_1
            most_recent_start_pipeline.builds << build_2
          end

          it 'returns the most recent diff start pipeline' do
            expect(pipeline).to eq(most_recent_start_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            build = build(:ci_build,
              :sast_report,
              pipeline: old_start_pipeline,
              project: project)

            old_start_pipeline.builds << build
          end

          it 'returns the latest start pipeline with security reports' do
            expect(pipeline).to eq(old_start_pipeline)
          end
        end
      end
    end
  end

  describe '#latest_comparison_pipeline_with_sbom_reports' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be(:base_pipeline) do
      create(
        :ci_pipeline,
        :with_test_reports,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    subject(:pipeline) { merge_request.latest_comparison_pipeline_with_sbom_reports }

    before do
      merge_request.update_head_pipeline
    end

    context 'when there are merge base pipelines' do
      let_it_be(:old_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      let_it_be(:most_recent_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      context 'when all pipelines have SBOM artifacts' do
        it 'returns the most recent merge base pipeline' do
          expect(pipeline).to eq(most_recent_merge_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have an SBOM artifact' do
        before do
          most_recent_merge_base_pipeline.job_artifacts.cyclonedx.delete_all
        end

        it 'returns the latest merge base pipeline with an SBOM artifact' do
          expect(pipeline).to eq(old_merge_base_pipeline)
        end
      end
    end

    context 'when there is no merge base pipeline' do
      let_it_be(:old_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      let_it_be(:most_recent_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      context 'when all pipelines have SBOM artifacts' do
        it 'returns the most recent base pipeline' do
          expect(pipeline).to eq(most_recent_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have an SBOM artifact' do
        before do
          most_recent_base_pipeline.job_artifacts.cyclonedx.delete_all
        end

        it 'returns the latest base pipeline with an SBOM artifact' do
          expect(pipeline).to eq(old_base_pipeline)
        end
      end
    end
  end

  describe '#diff_head_pipeline?' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    subject(:diff_head_pipeline) { merge_request.diff_head_pipeline?(pipeline) }

    context 'when the pipeline is the head pipeline' do
      let_it_be(:pipeline) do
        build_stubbed(:ee_ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it { is_expected.to be_truthy }
    end

    context 'when the pipeline is merged_results_pipeline' do
      let_it_be(:pipeline) do
        build_stubbed(:ci_pipeline, :merged_result_pipeline, :success, project: project, merge_request: merge_request)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the pipeline is base_pipeline' do
      let_it_be(:pipeline) do
        build_stubbed(:ee_ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_base_sha
        )
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#latest_scan_finding_comparison_pipeline' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be_with_reload(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    subject(:pipeline) { merge_request.latest_scan_finding_comparison_pipeline }

    before do
      merge_request.update_head_pipeline
    end

    context 'when there are merge base pipelines' do
      let_it_be(:old_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      let_it_be_with_reload(:most_recent_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      context 'when all pipelines have security reports' do
        it 'returns the most recent merge base pipeline' do
          expect(pipeline).to eq(most_recent_merge_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have security reports' do
        before do
          most_recent_merge_base_pipeline.job_artifacts.security_reports.delete_all
        end

        context 'when other merge base pipeline has security reports' do
          it 'returns the latest merge base pipeline with security reports' do
            expect(pipeline).to eq(old_merge_base_pipeline)
          end
        end

        context 'when no other merge base pipeline has security reports' do
          before do
            old_merge_base_pipeline.job_artifacts.security_reports.delete_all
          end

          context 'when base pipeline has security reports' do
            it 'returns the base pipeline' do
              expect(pipeline).to eq(base_pipeline)
            end
          end

          context 'when no base pipeline has security reports' do
            before do
              base_pipeline.job_artifacts.security_reports.delete_all

              most_recent_merge_base_pipeline.update!(status: :manual)
            end

            it 'returns nil' do
              expect(pipeline).to be_nil
            end
          end
        end
      end
    end

    context 'when there is no merge base pipeline' do
      let_it_be_with_refind(:old_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      let_it_be_with_refind(:most_recent_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      context 'when all pipelines have security reports' do
        it 'returns the most recent base pipeline' do
          expect(pipeline).to eq(most_recent_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have security reports' do
        before do
          most_recent_base_pipeline.job_artifacts.security_reports.delete_all
        end

        it 'returns the latest base pipeline with security reports' do
          expect(pipeline).to eq(old_base_pipeline)
        end

        context 'when no base pipeline has security reports' do
          before do
            base_pipeline.job_artifacts.security_reports.delete_all
            old_base_pipeline.job_artifacts.security_reports.delete_all
            most_recent_base_pipeline.job_artifacts.security_reports.delete_all
          end

          it 'returns nil' do
            expect(pipeline).to be_nil
          end
        end

        context 'when no base pipeline has completed' do
          before do
            base_pipeline.update!(status: :waiting_for_resource)
            old_base_pipeline.update!(status: :waiting_for_resource)
            most_recent_base_pipeline.update!(status: :waiting_for_resource)
          end

          context 'when comparison prior to pipeline completion is disabled' do
            it 'returns nil' do
              expect(pipeline).to be_nil
            end
          end
        end
      end

      context 'when there are multiple diff start pipelines' do
        let!(:old_diff_start_pipeline) do
          create(
            :ee_ci_pipeline,
            :with_cyclonedx_report,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_start_sha,
            created_at: 1.hour.ago
          )
        end

        let!(:most_recent_diff_start_pipeline) do
          create(
            :ee_ci_pipeline,
            :with_cyclonedx_report,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_start_sha,
            created_at: Time.current
          )
        end

        context 'when all pipelines have security reports' do
          it 'returns the most recent pipeline within the limit' do
            expect(pipeline).to eq(most_recent_diff_start_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            most_recent_diff_start_pipeline.job_artifacts.cyclonedx.delete_all
          end

          it 'returns the latest diff start pipeline with security reports' do
            expect(pipeline).to eq(old_diff_start_pipeline)
          end
        end

        context 'with child pipelines' do
          let!(:child_pipeline) do
            create(
              :ee_ci_pipeline,
              :with_cyclonedx_report,
              project: project,
              ref: merge_request.target_branch
            )
          end

          before do
            create(:ci_sources_pipeline,
              source_job: create(:ci_build, pipeline: most_recent_diff_start_pipeline, project: project),
              source_pipeline: most_recent_diff_start_pipeline,
              pipeline: child_pipeline)

            most_recent_diff_start_pipeline.job_artifacts.cyclonedx.delete_all
          end

          it 'considers child pipeline reports' do
            expect(pipeline).to eq(most_recent_diff_start_pipeline)
          end
        end
      end
    end

    context 'when there are no merge base and diff start pipelines' do
      before do
        base_pipeline.job_artifacts.security_reports.delete_all
      end

      it 'returns nil' do
        expect(pipeline).to be_nil
      end
    end
  end

  describe '#blocking_merge_requests_feature_available?' do
    let(:merge_request) { build_stubbed(:merge_request) }

    subject(:result) { merge_request.blocking_merge_requests_feature_available? }

    before do
      stub_licensed_features(blocking_merge_requests: blocking_merge_requests_enabled)
    end

    context 'when blocking_merge_requests feature is enabled' do
      let(:blocking_merge_requests_enabled) { true }

      it { is_expected.to be(true) }
    end

    context 'when blocking_merge_requests feature is disabled' do
      let(:blocking_merge_requests_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#license_scanning_feature_available?' do
    let(:merge_request) { build_stubbed(:merge_request) }

    subject(:result) { merge_request.license_scanning_feature_available? }

    before do
      stub_licensed_features(license_scanning: license_scanning_enabled)
    end

    context 'when license_scanning feature is enabled' do
      let(:license_scanning_enabled) { true }

      it { is_expected.to be(true) }
    end

    context 'when license_scanning feature is disabled' do
      let(:license_scanning_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#notify_approvers' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be_with_reload(:approvers) { create_list(:user, 2) }
    let_it_be(:approval_rule) do
      create(:approval_merge_request_rule, merge_request: merge_request, users: approvers)
    end

    it 'calls NotificationService.added_as_approver' do
      expect_any_instance_of(EE::NotificationService).to receive(:added_as_approver)
        .with(merge_request.wrapped_approval_rules.flat_map(&:approvers), merge_request)

      merge_request.notify_approvers
    end
  end

  describe '#has_changes_requested?' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    it { expect(merge_request.has_changes_requested?).to be_falsey }

    describe 'when merge request has changes requested' do
      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: create(:user))
      end

      it { expect(merge_request.has_changes_requested?).to be_truthy }
    end
  end

  describe '#create_requested_changes' do
    let_it_be(:user) { build_stubbed(:user) }

    it 'creates a merge request requested changes' do
      expect { merge_request.create_requested_changes(user) }.to change {
        merge_request.requested_changes.count
      }.from(0).to(1)
    end
  end

  describe '#destroy_requested_changes' do
    let_it_be(:user) { build_stubbed(:user) }

    before do
      create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project, user: user)
    end

    it 'destroys a merge request requested changes' do
      expect { merge_request.destroy_requested_changes(user) }.to change {
        merge_request.requested_changes.count
      }.from(1).to(0)
    end
  end

  describe '#requested_changes_for_users' do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, target_project: project)
    end

    let_it_be(:requested_changes) do
      create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project, user: user)
    end

    before do
      create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
        user: build_stubbed(:user))
    end

    it 'returns requested changes for user IDs' do
      expect(merge_request.requested_changes_for_users([user.id])).to contain_exactly(
        requested_changes
      )
    end
  end

  describe '#ai_review_merge_request_allowed?' do
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, target_project: project)
    end

    let_it_be(:current_user) { create(:user, developer_of: project) }

    subject(:ai_review_merge_request_allowed?) { merge_request.ai_review_merge_request_allowed?(current_user) }

    it 'delegates to Gitlab::Duo::CodeReview and checks create_note ability' do
      expect(Gitlab::Duo::CodeReview).to receive(:enabled?)
        .with(user: current_user, container: project).and_return(true)
      expect(Ability).to receive(:allowed?).with(current_user, :create_note, merge_request).and_return(true)

      expect(ai_review_merge_request_allowed?).to be(true)
    end

    context 'when user cannot create note' do
      let(:current_user) { create(:user, guest_of: project) }

      it 'returns false even if Duo Code Review is enabled' do
        allow(Gitlab::Duo::CodeReview).to receive(:enabled?).and_return(true)

        expect(ai_review_merge_request_allowed?).to be(false)
      end
    end
  end

  describe '#temporarily_unapproved?' do
    subject(:temporarily_unapproved) { merge_request.temporarily_unapproved? }

    context 'when the MR is not temporarily unapproved' do
      it 'returns false' do
        expect(temporarily_unapproved).to be(false)
      end
    end

    context 'when the MR is temporarily unapproved' do
      before do
        merge_request.approval_state.temporarily_unapprove!
      end

      it 'returns true' do
        expect(temporarily_unapproved).to be(true)
      end
    end
  end

  describe '#ai_reviewable_diff_files' do
    let(:merge_request) { build_stubbed(:merge_request) }
    let(:diff_file_a) { instance_double(Gitlab::Diff::File, ai_reviewable?: true) }
    let(:diff_file_b) { instance_double(Gitlab::Diff::File, ai_reviewable?: false) }
    let(:diff_file_c) { instance_double(Gitlab::Diff::File, ai_reviewable?: true) }
    let(:diff_files) { [diff_file_a, diff_file_b, diff_file_c] }
    let(:diffs) { instance_double(Gitlab::Diff::FileCollection::MergeRequestDiff, diff_files: diff_files) }

    before do
      allow(merge_request).to receive(:diffs).and_return(diffs)
    end

    it 'returns only AI reviewable diff files' do
      expect(merge_request.ai_reviewable_diff_files).to match_array([diff_file_a, diff_file_c])
    end
  end

  describe '#squash_option' do
    let_it_be(:target_branch) { 'target_branch' }

    let(:merge_request) { build(:merge_request, project: project, target_branch: target_branch) }
    let(:project_setting) { project.project_setting }

    subject { merge_request.squash_option }

    context 'when the target branch matches a wildcard protected branch' do
      let_it_be_with_refind(:protected_branch) { create(:protected_branch, name: '*', project_id: project.id) }

      it { is_expected.to eq(project_setting) }
    end

    context 'when the target branch exact matches a protected branch' do
      let_it_be_with_refind(:protected_branch) do
        create(:protected_branch, name: target_branch, project_id: project.id)
      end

      context 'and the protected branch has a defined squash_option' do
        let_it_be(:squash_option) do
          create(:branch_rule_squash_option, protected_branch: protected_branch, project: project)
        end

        it { is_expected.to eq(squash_option) }
      end

      context 'and the protected branch does not have a squash_option' do
        it { is_expected.to eq(project_setting) }
      end
    end

    it { is_expected.to eq(project_setting) }
  end

  describe '#missing_required_squash?' do
    using RSpec::Parameterized::TableSyntax

    context 'when the target branch is not protected' do
      where(:squash, :require_squash, :expected) do
        false | true  | true
        false | false | false
        true  | true  | false
        true  | false | false
      end

      with_them do
        let(:merge_request) { build_stubbed(:merge_request, squash: squash, project: project) }

        subject { merge_request.missing_required_squash? }

        before do
          allow(project.project_setting).to receive(:squash_always?).and_return(require_squash)
        end

        it { is_expected.to eq(expected) }
      end
    end

    context 'when the target branch is protected' do
      let_it_be(:protected_branch) { create(:protected_branch, name: 'feature', project: project) }

      where(:squash, :require_squash, :expected) do
        false | true  | true
        false | false | false
        true  | true  | false
        true  | false | false
      end

      with_them do
        let(:merge_request) { build_stubbed(:merge_request, squash: squash, project: project) }

        subject { merge_request.missing_required_squash? }

        before do
          allow(project.project_setting).to receive(:squash_always?).and_return(require_squash)
        end

        it { is_expected.to eq(expected) }
      end

      context 'when the target branch is protected and specifies a squash option' do
        let(:squash_option) do
          build_stubbed(:branch_rule_squash_option, protected_branch: protected_branch, project: project)
        end

        where(:squash, :project_require_squash, :require_squash, :expected) do
          false | false | true  | true
          false | true  | false | false
          true  | false | true  | false
          true  | true  | false | false
        end

        with_them do
          let(:merge_request) { build_stubbed(:merge_request, squash: squash, project: project) }

          subject { merge_request.missing_required_squash? }

          before do
            allow(project.project_setting).to receive(:squash_always?).and_return(project_require_squash)
            allow(merge_request).to receive(:squash_option).and_return(squash_option)
            allow(squash_option).to receive(:squash_always?).and_return(require_squash)
          end

          it { is_expected.to eq(expected) }
        end
      end
    end
  end

  describe '#schedule_policy_synchronization' do
    subject(:execute) { merge_request.schedule_policy_synchronization }

    it_behaves_like 'synchronizes policies for a merge request'
  end

  describe '#security_policies_with_branch_exceptions' do
    include_context 'with a security orchestration policy configuration'

    let_it_be(:security_policy) do
      create(:security_policy, content: {
        bypass_settings: {
          branches: [
            { source: { name: 'feature' }, target: { name: 'main' } }
          ]
        }
      }, security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, security_policy: security_policy)
    end

    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project, source_branch: 'feature',
        target_branch: 'main')
    end

    context 'when merge_request has approval rule with security policy' do
      let_it_be(:approval_rule) do
        create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
      end

      it 'returns the security policy that exempts the branch' do
        expect(merge_request.security_policies_with_branch_exceptions).to contain_exactly(security_policy)
      end

      it 'returns empty if no rules exempt the branch' do
        merge_request.update!(source_branch: 'other', target_branch: 'main')
        expect(merge_request.security_policies_with_branch_exceptions).to be_empty
      end
    end

    context 'when merge_request does not have approval rule with security policy' do
      it 'returns empty' do
        expect(merge_request.security_policies_with_branch_exceptions).to be_empty
      end
    end
  end

  describe '#security_policies_with_bypass_settings' do
    include_context 'with a security orchestration policy configuration'

    let_it_be(:user) { build_stubbed(:user) }

    let_it_be(:security_policy_with_bypass) do
      create(:security_policy, content: {
        bypass_settings: {
          users: [
            { id: user.id }
          ]
        }
      }, linked_projects: [project],
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:security_policy_without_bypass) do
      create(:security_policy, content: {
        bypass_settings: {}
      }, linked_projects: [project], policy_index: 1,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:security_policy_no_bypass_key) do
      create(:security_policy, content: {}, linked_projects: [project], policy_index: 2,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration)
    end

    let_it_be(:approval_policy_rule_with_bypass) do
      create(:approval_policy_rule, security_policy: security_policy_with_bypass)
    end

    let_it_be(:approval_policy_rule_without_bypass) do
      create(:approval_policy_rule, security_policy: security_policy_without_bypass)
    end

    let_it_be(:approval_policy_rule_no_bypass_key) do
      create(:approval_policy_rule, security_policy: security_policy_no_bypass_key)
    end

    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project, source_branch: 'feature',
        target_branch: 'main')
    end

    context 'when merge request has approval rules with security policies that have bypass settings' do
      let_it_be(:approval_rule_with_bypass) do
        create(:approval_merge_request_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule_with_bypass)
      end

      it 'returns security policies with bypass settings' do
        expect(merge_request.security_policies_with_bypass_settings).to contain_exactly(security_policy_with_bypass)
      end
    end

    context 'when merge request has approval rules with security policies without bypass settings' do
      let_it_be(:approval_rule_without_bypass) do
        create(:approval_merge_request_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule_without_bypass)
      end

      let_it_be(:approval_rule_no_bypass_key) do
        create(:approval_merge_request_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule_no_bypass_key)
      end

      it 'returns empty collection' do
        expect(merge_request.security_policies_with_bypass_settings).to be_empty
      end
    end

    context 'when merge request has approval rules without approval_policy_rule_id' do
      let_it_be(:approval_rule_without_policy) do
        create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: nil)
      end

      it 'returns empty collection' do
        expect(merge_request.security_policies_with_bypass_settings).to be_empty
      end
    end

    context 'when merge request has no approval rules' do
      it 'returns empty collection' do
        expect(merge_request.security_policies_with_bypass_settings).to be_empty
      end
    end

    context 'when merge request has mixed approval rules' do
      let_it_be(:approval_rule_with_bypass) do
        create(:approval_merge_request_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule_with_bypass)
      end

      let_it_be(:approval_rule_without_bypass) do
        create(:approval_merge_request_rule, merge_request: merge_request,
          approval_policy_rule: approval_policy_rule_without_bypass)
      end

      let_it_be(:approval_rule_without_policy) do
        create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: nil)
      end

      it 'returns only security policies with bypass settings' do
        expect(merge_request.security_policies_with_bypass_settings).to contain_exactly(security_policy_with_bypass)
      end
    end
  end

  describe '#approval_rules_editable_by?' do
    RSpec.shared_examples 'not editable by user' do
      it 'is not editable by user' do
        expect(editable).to be_falsey
      end
    end

    RSpec.shared_examples 'editable by user' do
      it 'is editable by user' do
        expect(editable).to be_truthy
      end
    end

    subject(:editable) { merge_request.approval_rules_editable_by?(user) }

    context 'when user is set' do
      let(:user) { merge_request.author }

      context 'when project can override approvers' do
        let_it_be(:user) { create(:user) }
        let_it_be(:project) do
          create(:project, :public, :merge_requests_private, disable_overriding_approvers_per_merge_request: false)
        end

        context 'when the merge request can be updated' do
          context 'when the user is the assignee or author' do
            before do
              merge_request.update!(author: user)
            end

            context 'when the user is a developer member' do
              before_all do
                project.add_developer(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the user is a reporter member' do
              before_all do
                project.add_reporter(user)
              end

              it_behaves_like 'not editable by user'
            end
          end

          context 'when user is not the author or assignee' do
            context 'when the user is a maintainer' do
              before_all do
                project.add_maintainer(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the user is a owner' do
              before_all do
                project.add_owner(user)
              end

              it_behaves_like 'editable by user'
            end

            context 'when the user is a developer' do
              before_all do
                project.add_developer(user)
              end

              it_behaves_like 'not editable by user'
            end

            context 'when the user is an admin' do
              let_it_be(:user) { build_stubbed(:admin) }

              before do
                allow(user).to receive(:can_admin_all_resources?).and_return(true)
              end

              it_behaves_like 'editable by user'
            end
          end
        end

        context 'when the merge request can not be updated' do
          let(:project) do
            create(:project, :public, :merge_requests_private, disable_overriding_approvers_per_merge_request: false)
          end

          it_behaves_like 'not editable by user' do
            before do
              # Need to ensure MR is created before turning off the merge requests for the project
              merge_request
              project.project_feature.merge_requests_access_level = Featurable::DISABLED
              project.save!
            end
          end
        end
      end

      context 'when project can not override approvers' do
        let(:project) { create(:project, disable_overriding_approvers_per_merge_request: true) }

        it_behaves_like 'not editable by user'
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it_behaves_like 'not editable by user'
    end
  end

  describe '#duo_code_review_progress_note' do
    subject(:progress_note) { merge_request.duo_code_review_progress_note }

    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    context 'when merge request does not have a progress note' do
      it 'returns nil' do
        expect(progress_note).to be_nil
      end
    end

    context 'when merge request has a progress note' do
      let(:review_bot) { build_stubbed(:user, user_type: :duo_code_review_bot) }
      let!(:note) do
        ::SystemNotes::MergeRequestsService.new(
          noteable: merge_request,
          container: merge_request.project,
          author: review_bot
        ).duo_code_review_started
      end

      it 'returns the progress note' do
        expect(progress_note.id).to eq(note.id)
      end
    end
  end

  describe '#duo_code_reviewed?' do
    subject(:duo_code_reviewed) { merge_request.duo_code_reviewed? }

    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }

    before do
      allow_next_instance_of(Users::Internal) do |instance|
        allow(instance).to receive(:duo_code_review_bot).and_return(duo_code_review_bot)
      end
    end

    context 'when the duo code review bot does not exist for the organization' do
      before do
        allow_next_instance_of(Users::Internal) do |instance|
          allow(instance).to receive(:duo_code_review_bot).and_return(nil)
        end
      end

      it 'returns false' do
        expect(duo_code_reviewed).to be(false)
      end
    end

    context 'when the bot is not a reviewer of the MR' do
      it 'returns false' do
        expect(duo_code_reviewed).to be(false)
      end
    end

    context 'when the bot is a reviewer with unreviewed state' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: :unreviewed)
      end

      it 'returns false' do
        expect(duo_code_reviewed).to be(false)
      end
    end

    context 'when the bot has reviewed the MR' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: :reviewed)
      end

      it 'returns true' do
        expect(duo_code_reviewed).to be(true)
      end
    end
  end

  describe '#preserve_open_policy_dismissals!' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:merge_request) do
      create(
        :merge_request,
        :merged,
        source_project:
        project,
        target_project: project,
        source_branch: 'feature-branch',
        target_branch: project.default_branch
      )
    end

    subject(:preserve_open_policy_dismissals) { merge_request.preserve_open_policy_dismissals! }

    include_context 'with a security orchestration policy configuration'

    context 'when merge request is merged' do
      context 'when there are open policy dismissals' do
        let_it_be(:security_policy_1) do
          create(:security_policy,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:security_policy_2) do
          create(:security_policy, policy_index: 1,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:security_policy_3) do
          create(:security_policy, policy_index: 2,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration)
        end

        let_it_be(:open_dismissal_1) do
          create(:policy_dismissal, merge_request: merge_request, project: project, security_policy: security_policy_1)
        end

        let_it_be(:open_dismissal_2) do
          create(:policy_dismissal, merge_request: merge_request, project: project, security_policy: security_policy_2)
        end

        let_it_be(:preserved_dismissal) do
          create(:policy_dismissal, merge_request: merge_request, project: project, status: 1,
            security_policy: security_policy_3)
        end

        it 'preserves all open policy dismissals' do
          expect { preserve_open_policy_dismissals }
            .to change { open_dismissal_1.reload.status }.from('open').to('preserved')
            .and change { open_dismissal_2.reload.status }.from('open').to('preserved')
            .and not_change { preserved_dismissal.reload.status }
        end
      end
    end

    context 'when merge request is not merged' do
      let_it_be(:security_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:open_dismissal) do
        create(:policy_dismissal, merge_request: merge_request, project: project, security_policy: security_policy)
      end

      before do
        allow(merge_request).to receive(:merged?).and_return(false)
      end

      it 'returns early without processing dismissals' do
        expect { preserve_open_policy_dismissals }
          .not_to change { open_dismissal.reload.status }
      end
    end

    context 'when merge request was not merged into the default branch' do
      let_it_be(:merge_request) do
        create(:merge_request, :merged, source_project: project, target_project: project, target_branch: 'feature')
      end

      let_it_be(:security_policy) do
        create(:security_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration)
      end

      let_it_be(:open_dismissal) do
        create(:policy_dismissal, merge_request: merge_request, project: project, security_policy: security_policy)
      end

      it 'returns early without processing dismissals' do
        expect { preserve_open_policy_dismissals }
          .not_to change { open_dismissal.reload.status }
      end
    end
  end

  describe '#all_target_branch_pipelines' do
    include_context 'with a merge request'

    let_it_be(:diff_base_pipeline) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    let_it_be(:target_branch_sha_pipeline) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.target_branch_sha)
    end

    let_it_be(:other_ref_pipeline) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.source_branch)
    end

    it 'returns only pipelines on the target branch' do
      expect(merge_request.all_target_branch_pipelines).to contain_exactly(diff_base_pipeline,
        target_branch_sha_pipeline)
    end
  end

  describe '#target_branch_comparison_pipelines' do
    include_context 'with a merge request'

    let_it_be(:base_old) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    let_it_be(:base_new) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    let_it_be(:start_old) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.diff_start_sha)
    end

    let_it_be(:start_new) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: merge_request.diff_start_sha)
    end

    let_it_be(:additional_pipeline_1) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: 'additional_sha_1')
    end

    let_it_be(:additional_pipeline_2) do
      create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: 'additional_sha_2'
      )
    end

    let(:max_shas) { MergeRequest::MAX_CHECKED_ADDITIONAL_SHAS_FOR_SECURITY_REPORT_COMPARISON }

    before do
      additional_commits = [
        instance_double(Commit, id: 'additional_sha_1'),
        instance_double(Commit, id: 'additional_sha_2')
      ]
      allow(merge_request.target_project.repository).to receive(:commits)
                                                          .with(
                                                            merge_request.target_branch,
                                                            limit: max_shas
                                                          ).and_return(additional_commits)
    end

    subject { merge_request.target_branch_comparison_pipelines.to_a }

    it 'includes pipelines from additional target branch commits' do
      expect(subject).to include(base_new, base_old, start_new, start_old, additional_pipeline_1, additional_pipeline_2)
    end

    it 'uses the batch loading method for retrieving pipelines' do
      expect(merge_request).to receive(:batch_loaded_recent_target_branch_pipelines_for_shas).and_call_original

      subject
    end

    it 'only includes pipelines for the target branch shas' do
      unrelated = create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch,
        sha: project.commit.id)

      expect(subject).not_to include(unrelated)
    end

    context 'when batch_loaded_recent_target_branch_pipelines_for_shas raises an error' do
      before do
        allow(merge_request).to receive(:batch_loaded_recent_target_branch_pipelines_for_shas)
                                  .and_raise(ActiveRecord::QueryCanceled.new("statement timeout"))
      end

      it 'falls back to lazy_loaded_recent_target_branch_pipelines_for_shas' do
        expect(merge_request).to receive(:lazy_loaded_recent_target_branch_pipelines_for_shas).and_call_original

        subject
      end

      it 'returns pipelines from the lazy loaded query' do
        expect(subject).to contain_exactly(base_new, base_old, start_new, start_old)
      end
    end

    context 'when target_branch_comparison_pipelines is empty' do
      before do
        allow(merge_request.target_project.repository).to receive(:commits)
                                                            .with(
                                                              merge_request.target_branch,
                                                              limit: max_shas
                                                            ).and_return([])
        allow(merge_request).to receive(:diff_head_pipeline).and_return(nil)
        allow(merge_request).to receive(:diff_base_sha).and_return(nil)
        allow(merge_request).to receive(:diff_start_sha).and_return(nil)
      end

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#additional_target_branch_commit_shas_for_comparison' do
    include_context 'with a merge request'

    let(:max_shas) { MergeRequest::MAX_CHECKED_ADDITIONAL_SHAS_FOR_SECURITY_REPORT_COMPARISON }
    let :commits do
      Array.new(max_shas + 1) do |i|
        instance_double(Commit, id: "sha_#{i}")
      end
    end

    subject { merge_request.additional_target_branch_commit_shas_for_comparison }

    before do
      allow(merge_request.target_project.repository).to receive(:commits)
                                                          .with(merge_request.target_branch,
                                                            limit: max_shas)
                                                          .and_return(commits.first(max_shas))
    end

    it 'respects the maximum limit' do
      expect(subject.size).to be <= max_shas
    end

    it 'returns commit SHAs from the target branch' do
      expect(subject).to be_an(Array)
      expect(subject.size).to eq(max_shas)
      expect(subject).to match_array(commits.uniq.map(&:id).first(max_shas))
    end

    it 'returns unique commit SHAs' do
      allow(merge_request.target_project.repository).to receive(:commits)
                                                          .with(merge_request.target_branch,
                                                            limit: max_shas)
                                                          .and_return([commits[0], commits[1], commits[1]])

      expect(subject).to eq(subject.uniq)
    end
  end

  describe '#recent_target_branch_pipelines_for_shas' do
    include_context 'with a merge request'

    let(:sha_1) { 'abc123' }
    let(:sha_2) { 'def456' }

    subject(:pipelines) { merge_request.batch_loaded_recent_target_branch_pipelines_for_shas(shas) }

    context 'with multiple SHAs' do
      let(:shas) { [sha_1, sha_2] }

      let!(:pipeline_1) do
        create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_1)
      end

      let!(:pipeline_2) do
        create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_2)
      end

      it 'returns pipelines for all given SHAs' do
        expect(pipelines).to contain_exactly(pipeline_1, pipeline_2)
      end
    end

    context 'when a SHA has multiple pipelines' do
      let(:shas) { [sha_1] }

      let!(:older_pipeline) do
        create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_1)
      end

      let!(:newer_pipeline) do
        create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_1)
      end

      it 'returns pipelines ordered by ID descending' do
        expect(pipelines).to eq([newer_pipeline, older_pipeline])
      end
    end

    context 'when filtering by branch and project' do
      let(:shas) { [sha_1] }

      let!(:correct_pipeline) do
        create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_1)
      end

      let!(:wrong_branch_pipeline) do
        create(:ci_pipeline, :success, project: project, ref: 'other-branch', sha: sha_1)
      end

      it 'only returns pipelines from the target branch' do
        expect(pipelines).to contain_exactly(correct_pipeline)
      end
    end

    context 'when limiting results per SHA' do
      let(:shas) { [sha_1] }
      let(:max_pipelines) { MergeRequest::MAX_CHECKED_PIPELINES_FOR_SECURITY_REPORT_COMPARISON }

      before do
        (max_pipelines + 2).times do
          create(:ci_pipeline, :success, project: project, ref: merge_request.target_branch, sha: sha_1)
        end
      end

      it 'limits pipelines per SHA to the maximum' do
        expect(pipelines.count).to eq(max_pipelines)
      end
    end
  end

  describe '#duo_vulnerability_fix?' do
    let_it_be(:project) { build_stubbed(:project) }

    context 'when source branch starts with duo/fix/' do
      subject(:merge_request) do
        build(:merge_request, source_project: project,
          source_branch: "#{described_class::DUO_VULNERABILITY_FIX_BRANCH_PREFIX}123-fix-xss")
      end

      it 'returns true' do
        expect(merge_request.duo_vulnerability_fix?).to be true
      end
    end

    context 'when source branch does not start with duo/fix/' do
      subject(:merge_request) { build(:merge_request, source_project: project, source_branch: 'feature/something') }

      it 'returns false' do
        expect(merge_request.duo_vulnerability_fix?).to be false
      end
    end
  end

  describe '#dependency_management_auto_remediation?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }

    context 'when merge request has a vulnerability link and source branch starts with dependency management prefix' do
      subject(:merge_request) do
        create(:merge_request, source_project: project, author: user,
          source_branch: "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/rails-6.x")
      end

      before do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns true' do
        expect(merge_request.dependency_management_auto_remediation?).to be true
      end
    end

    context 'when merge request has a vulnerability link but source branch does not use the prefix' do
      subject(:merge_request) do
        create(:merge_request, :unique_branches, source_project: project, author: user)
      end

      before do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns false' do
        expect(merge_request.dependency_management_auto_remediation?).to be false
      end
    end

    context 'when merge request has no vulnerability links but source branch uses the prefix' do
      subject(:merge_request) do
        create(:merge_request, source_project: project, author: user,
          source_branch: "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/rails-6.x")
      end

      it 'returns false' do
        expect(merge_request.dependency_management_auto_remediation?).to be false
      end
    end
  end

  describe '#created_by_agentic_vr?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }

    context 'when merge request has a vulnerability link and source branch starts with duo/fix/' do
      subject(:merge_request) do
        create(:merge_request, source_project: project, author: user,
          source_branch: "#{described_class::DUO_VULNERABILITY_FIX_BRANCH_PREFIX}123-fix-xss")
      end

      before do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns true' do
        expect(merge_request.created_by_agentic_vr?).to be true
      end
    end

    context 'when merge request has a vulnerability link but source branch does not start with duo/fix/' do
      subject(:merge_request) do
        create(:merge_request, :unique_branches, source_project: project, author: user)
      end

      before do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns false' do
        expect(merge_request.created_by_agentic_vr?).to be false
      end
    end

    context 'when merge request has no vulnerability links but source branch starts with duo/fix/' do
      subject(:merge_request) do
        create(:merge_request, source_project: project, author: user,
          source_branch: "#{described_class::DUO_VULNERABILITY_FIX_BRANCH_PREFIX}456-fix-sqli")
      end

      it 'returns false' do
        expect(merge_request.created_by_agentic_vr?).to be false
      end
    end

    context 'when merge request has no vulnerability links and a regular branch' do
      subject(:merge_request) do
        create(:merge_request, :unique_branches, source_project: project, author: user)
      end

      it 'returns false' do
        expect(merge_request.created_by_agentic_vr?).to be false
      end
    end
  end

  describe '#dependency_management_mr?' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:service_account) do
      build_stubbed(:user, :service_account,
        name: ::DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
    end

    let(:source_branch) { "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/rails-6.x" }
    let(:author) { service_account }

    subject(:merge_request) do
      build(:merge_request, source_project: project, author: author, source_branch: source_branch)
    end

    context 'when the branch uses the dependency management prefix and the author is the service account' do
      it { expect(merge_request.dependency_management_mr?).to be true }
    end

    context 'when the source branch does not use the dependency management prefix' do
      let(:source_branch) { 'feature' }

      it { expect(merge_request.dependency_management_mr?).to be false }
    end

    context 'when the author is not a service account' do
      let(:author) do
        build_stubbed(:user, name: ::DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
      end

      it { expect(merge_request.dependency_management_mr?).to be false }
    end

    context 'when the author is a service account with a different name' do
      let(:author) { build_stubbed(:user, :service_account, name: 'Some Other Bot') }

      it { expect(merge_request.dependency_management_mr?).to be false }
    end

    context 'when the source branch is nil' do
      let(:source_branch) { nil }

      it { expect(merge_request.dependency_management_mr?).to be false }
    end

    context 'when the author is nil' do
      let(:author) { nil }

      it { expect(merge_request.dependency_management_mr?).to be false }
    end
  end

  describe '#duo_dependency_bump_breaking_changes_available?' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:service_account) do
      build_stubbed(:user, :service_account,
        name: ::DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
    end

    let(:source_branch) { "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/rails-6.x" }
    let(:project_available) { true }

    subject(:merge_request) do
      build(:merge_request, source_project: project, author: service_account, source_branch: source_branch)
    end

    before do
      allow(project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(project_available)
    end

    context 'when the MR is a dependency management MR and the project allows the flow' do
      it { expect(merge_request.duo_dependency_bump_breaking_changes_available?).to be true }
    end

    context 'when the MR is not a dependency management MR' do
      let(:source_branch) { 'feature' }

      it 'returns false without checking project availability' do
        expect(project).not_to receive(:duo_dependency_bump_breaking_changes_available?)
        expect(merge_request.duo_dependency_bump_breaking_changes_available?).to be false
      end
    end

    context 'when the project does not allow the flow' do
      let(:project_available) { false }

      it { expect(merge_request.duo_dependency_bump_breaking_changes_available?).to be false }
    end
  end

  describe '.mergeable_state_checks_by_tier' do
    it 'appends EE checks after CE checks within each tier' do
      tiers = described_class.mergeable_state_checks_by_tier

      expect(tiers).to eq(
        trivial: [
          ::MergeRequests::Mergeability::CheckOpenStatusService,
          ::MergeRequests::Mergeability::CheckDraftStatusService,
          ::MergeRequests::Mergeability::CheckExternalStatusChecksPassedService,
          ::MergeRequests::Mergeability::CheckJiraStatusService
        ],
        light: [
          ::MergeRequests::Mergeability::CheckMergeTimeService,
          ::MergeRequests::Mergeability::CheckBlockedByOtherMrsService,
          ::MergeRequests::Mergeability::CheckRequestedChangesService,
          ::MergeRequests::Mergeability::CheckMergeRequestTitleRegexService,
          ::MergeRequests::Mergeability::CheckSecurityPolicyViolationsService
        ],
        heavy: [
          ::MergeRequests::Mergeability::CheckLfsFileLocksService,
          ::MergeRequests::Mergeability::CheckDiscussionsStatusService,
          ::MergeRequests::Mergeability::CheckCiStatusService,
          ::MergeRequests::Mergeability::CheckCommitsStatusService,
          ::MergeRequests::Mergeability::CheckPathLocksService,
          ::MergeRequests::Mergeability::CheckApprovedService,
          ::MergeRequests::Mergeability::CheckSecurityPolicyPipelineStatusService
        ]
      )
    end

    it 'executes tiers in order: trivial, light, heavy' do
      tier_keys = described_class.mergeable_state_checks_by_tier.keys
      expect(tier_keys).to eq(%i[trivial light heavy])
    end

    it 'runs the policy pipeline status last' do
      checks = described_class.mergeable_state_checks
      expect(checks.last).to eq(::MergeRequests::Mergeability::CheckSecurityPolicyPipelineStatusService)
    end
  end

  describe '.mergeable_state_checks' do
    it 'returns all checks flattened in tier order' do
      checks = described_class.mergeable_state_checks
      tiers = described_class.mergeable_state_checks_by_tier

      expect(checks).to eq(tiers.values.flatten)
    end
  end
end
