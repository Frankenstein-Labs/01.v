# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRuleLike, feature_category: :source_code_management do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:group1) { create(:group) }
  let(:group2) { create(:group) }

  let(:merge_request) { create(:merge_request) }

  let(:subject_traits) { [] }

  let(:abstract_class) do
    Class.new do
      def self.table_name
        'abstract_table'
      end

      def self.has_and_belongs_to_many(*); end
      def self.has_many(*); end
      def self.belongs_to(*); end
      def self.enum(*); end
      def self.validates(*); end
      def self.scope(*); end

      include ApprovalRuleLike
    end
  end

  describe 'abstract methods' do
    subject { abstract_class.new }

    %i[code_owner? regular? report_approver? any_approver?].each do |method|
      describe "##{method}" do
        it 'raises NotImplementedError' do
          expect { subject.public_send(method) }.to raise_error(NotImplementedError)
        end
      end
    end

    %i[audit_add audit_remove].each do |method|
      describe "##{method}" do
        it 'raises NotImplementedError' do
          expect { subject.public_send(method, anything) }.to raise_error(NotImplementedError)
        end
      end
    end
  end

  shared_examples 'approval rule like' do
    let(:group1_user) { create(:user) }
    let(:group2_user) { create(:user) }

    before do
      subject.users << user1
      subject.users << user2
      subject.groups << group1
      subject.groups << group2

      group1.add_guest(group1_user)
      group2.add_guest(group2_user)
    end

    it { is_expected.to respond_to(:rule_project) }

    describe 'abstract method implementations' do
      it 'implements all required abstract methods' do
        expect { subject.audit_add(subject) }.not_to raise_error
        expect { subject.audit_remove(subject) }.not_to raise_error
        expect { subject.code_owner? }.not_to raise_error
        expect { subject.regular? }.not_to raise_error
        expect { subject.report_approver? }.not_to raise_error
        expect { subject.any_approver? }.not_to raise_error
      end
    end

    describe '#approvers_include_user?' do
      let(:rule) { subject.class.find(subject.id) }

      it 'returns true for a contained user' do
        expect(rule.approvers_include_user?(user1)).to be_truthy
      end

      it 'returns true for a group user' do
        expect(rule.approvers_include_user?(group1_user)).to be_truthy
      end

      it 'returns false for a missing user' do
        expect(rule.approvers_include_user?(user3)).to be_falsey
      end

      context 'when the user relations are already loaded' do
        it 'returns true for a contained user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user1)).to be_truthy
        end

        it 'returns true for a group user' do
          rule.group_members.to_a

          expect(rule.approvers_include_user?(group1_user)).to be_truthy
        end

        it 'returns false for a missing user' do
          rule.users.to_a

          expect(rule.approvers_include_user?(user3)).to be_falsey
        end
      end

      context 'when dealing with team members and custom roles' do
        let_it_be(:group) { create(:group) }
        let_it_be(:group_project) { create(:project, group: group) }
        let_it_be(:custom_role) { create(:member_role, :instance, :admin_merge_request) }
        let_it_be(:team_member_with_role) { create(:user) }
        let_it_be(:team_member_without_role) { create(:user) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, custom_roles: [custom_role.id])
        end

        before do
          project = rule.project
          project.update!(group: group)

          rule.update!(scan_result_policy_read: scan_result_policy_read)

          create(:group_member, member_role: custom_role, user: team_member_with_role, group: group)
          create(:group_member, :developer, user: team_member_without_role, group: group)
        end

        context 'when scan_result_policy_read is nil' do
          before do
            rule.update!(scan_result_policy_read: nil)
          end

          it 'returns false' do
            expect(rule.approvers_include_user?(team_member_with_role)).to be_falsey
            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end

        context 'for a team member with the custom role' do
          it 'returns true when user belongs to custom role and false otherwise' do
            expect(rule.approvers_include_user?(team_member_with_role)).to be_truthy
            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end

        it 'returns false for a team member without the custom role' do
          expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
        end

        it 'returns false for a user who is not a team member' do
          non_team_member = create(:user)
          expect(rule.approvers_include_user?(non_team_member)).to be_falsey
        end

        context 'when the user relations are already loaded' do
          context 'for a team member with the custom role' do
            it 'returns true when user belongs to custom role and false otherwise' do
              rule.users.to_a
              rule.group_members.to_a

              expect(rule.approvers_include_user?(team_member_with_role)).to be_truthy
              expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
            end
          end

          it 'returns false for a team member without the custom role' do
            rule.users.to_a
            rule.group_members.to_a

            expect(rule.approvers_include_user?(team_member_without_role)).to be_falsey
          end
        end
      end
    end

    describe '#approvers' do
      shared_examples 'approvers contains the right users' do
        it 'contains users as direct members and group members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end

        context 'when some users are inactive' do
          before do
            user2.block!
            group2_user.block!
          end

          it 'returns users that are only active' do
            rule = subject.class.find(subject.id)

            expect(rule.approvers).to contain_exactly(user1, group1_user)
          end
        end
      end

      it_behaves_like 'approvers contains the right users'

      context 'when the user relations are already loaded' do
        before do
          subject.users.to_a
          subject.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { subject.approvers }.not_to exceed_query_limit(1)
        end

        it_behaves_like 'approvers contains the right users'
      end

      context 'when user is both a direct member and a group member' do
        before do
          group1.add_guest(user1)
          group2.add_guest(user2)
        end

        it 'contains only unique users' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end
      end

      context 'when scan_result_policy_read has role_approvers' do
        let_it_be(:user4) { create(:user) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, role_approvers: [Gitlab::Access::MAINTAINER])
        end

        before do
          subject.update!(scan_result_policy_read: scan_result_policy_read)
          group1.add_maintainer(user4)
        end

        it 'contains users as direct members and group members and role members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1, user2, group1_user, group2_user, user4)
        end
      end

      context 'when neither scan_result_policy_read nor approval_policy_rule is present' do
        it 'does not include role approvers' do
          expect(subject.approvers).to contain_exactly(user1, user2, group1_user, group2_user)
        end
      end
    end

    describe '#from_scan_result_policy?' do
      context 'when report_type is scan_finding' do
        let(:subject_traits) { %i[scan_finding] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to be(true)
        end
      end

      context 'when report_type is license_scanning' do
        let(:subject_traits) { %i[license_scanning] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to be(true)
        end
      end

      context 'when report_type is any_merge_request' do
        let(:subject_traits) { %i[any_merge_request] }

        it 'returns true' do
          expect(subject.from_scan_result_policy?).to be(true)
        end
      end

      context 'when report_type is nil' do
        before do
          subject.update!(report_type: nil)
        end

        it 'returns false' do
          expect(subject.from_scan_result_policy?).to be(false)
        end
      end
    end

    describe '#policy_name' do
      context 'when approval_policy_rule is not present' do
        it 'trims trailing digit coming from multiple rules belonging to the same policy' do
          subject.update!(name: 'Policy 1')
          expect(subject.policy_name).to eq('Policy')
        end
      end

      context 'when approval_policy_rule is present' do
        let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }
        let_it_be(:security_policy) { approval_policy_rule.security_policy }
        let_it_be(:policy_configuration) { security_policy.security_orchestration_policy_configuration }

        it 'gets name from security_policy' do
          subject.update!(scan_result_policy_read: create(:scan_result_policy_read,
            orchestration_policy_idx: security_policy.policy_index,
            rule_idx: approval_policy_rule.rule_index,
            security_orchestration_policy_configuration: policy_configuration))
          subject.update!(security_orchestration_policy_configuration: policy_configuration)

          expect(subject.policy_name).to eq(security_policy.name)
        end
      end
    end

    describe '#security_report_time_window' do
      context 'when approval_policy_rule is not present' do
        it 'returns nil' do
          expect(subject.security_report_time_window).to be_nil
        end
      end

      context 'when approval_policy_rule is present' do
        let_it_be_with_reload(:security_policy) { create(:security_policy, :approval_policy) }
        let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

        before do
          subject.update!(approval_policy_rule: approval_policy_rule)
          security_policy.clear_memoization(:policy_content)
          security_policy.clear_memoization(:policy_tuning)
        end

        context 'when security_policy has no policy_tuning' do
          it 'returns nil' do
            expect(subject.security_report_time_window).to be_nil
          end
        end

        context 'when security_policy has policy_tuning without security_report_time_window' do
          before do
            security_policy.update!(content: { policy_tuning: {} })
          end

          it 'returns nil' do
            expect(subject.security_report_time_window).to be_nil
          end
        end

        context 'when security_policy has policy_tuning with security_report_time_window' do
          let(:time_window) { 7 }

          before do
            security_policy.update!(content: { policy_tuning: { security_report_time_window: time_window } })
          end

          it 'returns the security_report_time_window value' do
            expect(subject.security_report_time_window).to eq(time_window)
          end
        end
      end
    end

    describe '#warn_mode_policy?' do
      let_it_be(:approval_policy_rule) { nil }

      before do
        allow(subject).to receive(:approval_policy_rule).and_return(approval_policy_rule)
      end

      specify do
        expect(subject.warn_mode_policy?).to be(false)
      end

      context 'when approval_policy_rule is present' do
        let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }
        let_it_be(:security_policy) { approval_policy_rule.security_policy }

        specify do
          expect(subject.warn_mode_policy?).to be(false)
        end

        context 'and policy is in warn mode' do
          let_it_be(:security_policy) { create(:security_policy, content: { enforcement_type: 'warn' }) }
          let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

          specify do
            expect(subject.warn_mode_policy?).to be(true)
          end
        end
      end
    end

    describe '#scanners_with_default_fallback' do
      let(:specified_scanners) { %w[dependency_scanning secret_detection] }

      before do
        subject.scanners = specified_scanners
      end

      it { expect(subject.scanners_with_default_fallback).to eq(specified_scanners) }

      context 'when scanners are empty' do
        let(:specified_scanners) { [] }

        it { expect(subject.scanners_with_default_fallback).to eq(ApprovalProjectRule::SUPPORTED_SCANNERS) }
      end

      context 'when approval_policy_rule has scanners with per-scanner attributes' do
        let(:specified_scanners) { %w[sast] }
        let(:policy_rule) do
          create(:approval_policy_rule, :scan_finding, security_policy: create(:security_policy), content: {
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } },
              { 'type' => 'container_scanning', 'vulnerability_attributes' => { 'known_exploited' => true } }
            ],
            'severity_levels' => %w[critical],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        before do
          subject.approval_policy_rule = policy_rule
        end

        it 'returns scanner types from configurations' do
          expect(subject.scanners_with_default_fallback).to eq(%w[dependency_scanning container_scanning])
        end
      end
    end

    describe '#vulnerability_attribute_false_positive' do
      context 'when scan_result_policy_read is nil' do
        before do
          subject.scan_result_policy_read = nil
        end

        it 'returns nil' do
          expect(subject.vulnerability_attribute_false_positive).to be_nil
        end
      end

      context 'when scan_result_policy_read exists' do
        let(:scan_result_policy_read) do
          build(:scan_result_policy_read, vulnerability_attributes: vulnerability_attributes)
        end

        before do
          subject.scan_result_policy_read = scan_result_policy_read
        end

        context 'when vulnerability_attributes is nil' do
          let(:vulnerability_attributes) { nil }

          it 'returns nil' do
            expect(subject.vulnerability_attribute_false_positive).to be_nil
          end
        end

        context 'when vulnerability_attributes contains false_positive as true' do
          let(:vulnerability_attributes) { { 'false_positive' => true } }

          it 'returns true' do
            expect(subject.vulnerability_attribute_false_positive).to be(true)
          end
        end

        context 'when vulnerability_attributes contains false_positive as false' do
          let(:vulnerability_attributes) { { 'false_positive' => false } }

          it 'returns false' do
            expect(subject.vulnerability_attribute_false_positive).to be(false)
          end
        end
      end
    end

    describe '#vulnerability_attribute_fix_available' do
      context 'when scan_result_policy_read is nil' do
        before do
          subject.scan_result_policy_read = nil
        end

        it 'returns nil' do
          expect(subject.vulnerability_attribute_fix_available).to be_nil
        end
      end

      context 'when scan_result_policy_read exists' do
        let(:scan_result_policy_read) do
          build(:scan_result_policy_read, vulnerability_attributes: vulnerability_attributes)
        end

        before do
          subject.scan_result_policy_read = scan_result_policy_read
        end

        context 'when vulnerability_attributes is nil' do
          let(:vulnerability_attributes) { nil }

          it 'returns nil' do
            expect(subject.vulnerability_attribute_fix_available).to be_nil
          end
        end

        context 'when vulnerability_attributes contains fix_available as true' do
          let(:vulnerability_attributes) { { 'fix_available' => true } }

          it 'returns true' do
            expect(subject.vulnerability_attribute_fix_available).to be(true)
          end
        end

        context 'when vulnerability_attributes contains fix_available as false' do
          let(:vulnerability_attributes) { { 'fix_available' => false } }

          it 'returns false' do
            expect(subject.vulnerability_attribute_fix_available).to be(false)
          end
        end
      end
    end

    describe '#vulnerability_attribute_known_exploited' do
      context 'when scan_result_policy_read is nil' do
        before do
          subject.scan_result_policy_read = nil
        end

        it 'returns nil' do
          expect(subject.vulnerability_attribute_known_exploited).to be_nil
        end
      end

      context 'when scan_result_policy_read exists' do
        let(:scan_result_policy_read) do
          build(:scan_result_policy_read, vulnerability_attributes: vulnerability_attributes)
        end

        before do
          subject.scan_result_policy_read = scan_result_policy_read
        end

        context 'when vulnerability_attributes is nil' do
          let(:vulnerability_attributes) { nil }

          it 'returns nil' do
            expect(subject.vulnerability_attribute_known_exploited).to be_nil
          end
        end

        context 'when vulnerability_attributes contains known_exploited as true' do
          let(:vulnerability_attributes) { { 'known_exploited' => true } }

          it 'returns true' do
            expect(subject.vulnerability_attribute_known_exploited).to be(true)
          end
        end

        context 'when vulnerability_attributes contains known_exploited as false' do
          let(:vulnerability_attributes) { { 'known_exploited' => false } }

          it 'returns false' do
            expect(subject.vulnerability_attribute_known_exploited).to be(false)
          end
        end
      end
    end

    describe '#vulnerability_attribute_epss_score' do
      context 'when scan_result_policy_read is nil' do
        before do
          subject.scan_result_policy_read = nil
        end

        it 'returns a empty hash' do
          expect(subject.vulnerability_attribute_epss_score).to eq({})
        end
      end

      context 'when scan_result_policy_read exists' do
        let(:scan_result_policy_read) do
          build(:scan_result_policy_read, vulnerability_attributes: vulnerability_attributes)
        end

        before do
          subject.scan_result_policy_read = scan_result_policy_read
        end

        context 'when vulnerability_attributes is nil' do
          let(:vulnerability_attributes) { nil }

          it 'returns a empty hash' do
            expect(subject.vulnerability_attribute_epss_score).to eq({})
          end
        end

        context 'when vulnerability_attributes does not contain epss_score' do
          let(:vulnerability_attributes) { { 'other_attribute' => 'value' } }

          it 'returns a empty hash' do
            expect(subject.vulnerability_attribute_epss_score).to eq({})
          end
        end

        context 'when vulnerability_attributes contains epss_score' do
          let(:vulnerability_attributes) do
            {
              'epss_score' => {
                'operator' => 'greater_than',
                'value' => 0.8
              }
            }
          end

          it 'returns the epss_score hash with symbolized keys' do
            expect(subject.vulnerability_attribute_epss_score).to eq({
              operator: 'greater_than',
              value: 0.8
            })
          end
        end

        context 'when vulnerability_attributes contains invalid epss_score value' do
          let(:vulnerability_attributes) { { 'epss_score' => 'unknown' } }

          it 'returns a empty hash' do
            expect(subject.vulnerability_attribute_epss_score).to eq({})
          end
        end
      end
    end

    describe '#vulnerability_attribute_enrichment_data_unavailable_action' do
      shared_examples_for 'returns nil' do
        it 'returns nil' do
          expect(subject.vulnerability_attribute_enrichment_data_unavailable_action).to be_nil
        end
      end

      context 'when scan_result_policy_read is nil' do
        before do
          subject.scan_result_policy_read = nil
        end

        it_behaves_like 'returns nil'
      end

      context 'when scan_result_policy_read exists' do
        let(:scan_result_policy_read) do
          build(:scan_result_policy_read, vulnerability_attributes: vulnerability_attributes)
        end

        before do
          subject.scan_result_policy_read = scan_result_policy_read
        end

        context 'when vulnerability_attributes is nil' do
          let(:vulnerability_attributes) { nil }

          it_behaves_like 'returns nil'
        end

        context 'when enrichment_data_unavailable is not set' do
          let(:vulnerability_attributes) { { 'fix_available' => true } }

          it_behaves_like 'returns nil'
        end

        context 'when enrichment_data_unavailable action is block' do
          let(:vulnerability_attributes) do
            {
              'enrichment_data_unavailable' => {
                'action' => 'block'
              }
            }
          end

          it 'returns block' do
            expect(subject.vulnerability_attribute_enrichment_data_unavailable_action).to eq('block')
          end
        end

        context 'when enrichment_data_unavailable action is ignore' do
          let(:vulnerability_attributes) do
            {
              'enrichment_data_unavailable' => {
                'action' => 'ignore'
              }
            }
          end

          it 'returns ignore' do
            expect(subject.vulnerability_attribute_enrichment_data_unavailable_action).to eq('ignore')
          end
        end

        context 'when enrichment_data_unavailable is empty hash' do
          let(:vulnerability_attributes) do
            {
              'enrichment_data_unavailable' => {}
            }
          end

          it_behaves_like 'returns nil'
        end

        context 'when combined with other vulnerability attributes' do
          let(:vulnerability_attributes) do
            {
              'fix_available' => true,
              'known_exploited' => true,
              'epss_score' => { 'operator' => 'greater_than', 'value' => 0.5 },
              'enrichment_data_unavailable' => { 'action' => 'block' }
            }
          end

          it 'returns the enrichment_data_unavailable action' do
            expect(subject.vulnerability_attribute_enrichment_data_unavailable_action).to eq('block')
          end
        end
      end
    end

    describe '#scanner_configurations' do
      context 'when approval_policy_rule is nil' do
        before do
          subject.approval_policy_rule = nil
        end

        it 'returns nil' do
          expect(subject.scanner_configurations).to be_nil
        end
      end

      context 'when approval_policy_rule is not scan_finding type' do
        let(:policy_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: create(:security_policy))
        end

        before do
          subject.approval_policy_rule = policy_rule
        end

        it 'returns nil' do
          expect(subject.scanner_configurations).to be_nil
        end
      end

      context 'when approval_policy_rule has legacy scanner format (string array)' do
        let(:policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy), content: {
            'branches' => [],
            'scanners' => %w[sast dependency_scanning],
            'severity_levels' => %w[critical high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        before do
          subject.approval_policy_rule = policy_rule
        end

        it 'returns nil because no atomic scanner attributes are present' do
          expect(subject.scanner_configurations).to be_nil
        end
      end

      context 'when approval_policy_rule has scanners with per-scanner attributes' do
        let(:policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy), content: {
            'branches' => [],
            'scanners' => [
              { 'type' => 'sast',
                'vulnerability_attributes' => { 'fix_available' => true } },
              { 'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'known_exploited' => true } }
            ],
            'severity_levels' => %w[critical high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0,
            'vulnerability_attributes' => { 'fix_available' => false }
          })
        end

        before do
          subject.approval_policy_rule = policy_rule
        end

        it 'returns scanner configurations with symbolized keys' do
          result = subject.scanner_configurations

          expect(result).to be_an(Array)
          expect(result.size).to eq(2)
          expect(result.first).to include(type: 'sast',
            vulnerability_attributes: { fix_available: true })
          expect(result.second).to include(
            type: 'dependency_scanning', vulnerability_attributes: { known_exploited: true }
          )
        end
      end

      context 'when approval_policy_rule has per-scanner severity and state overrides' do
        let(:policy_rule) do
          create(:approval_policy_rule, security_policy: create(:security_policy), content: {
            'branches' => [],
            'scanners' => [
              {
                'type' => 'sast',
                'severity_levels' => %w[high critical],
                'vulnerability_states' => %w[detected],
                'vulnerabilities_allowed' => 1,
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[low],
            'vulnerability_states' => %w[confirmed],
            'vulnerabilities_allowed' => 5
          })
        end

        before do
          subject.approval_policy_rule = policy_rule
        end

        it 'returns configurations with per-scanner overrides' do
          result = subject.scanner_configurations

          expect(result.first).to include(
            type: 'sast',
            severity_levels: %w[high critical],
            vulnerability_states: %w[detected],
            vulnerabilities_allowed: 1
          )
        end
      end
    end

    describe 'validation' do
      context 'when value is too big' do
        it 'is invalid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX + 1

          expect(subject).to be_invalid
          expect(subject.errors.key?(:approvals_required)).to be(true)
        end
      end

      context 'when value is within limit' do
        it 'is valid' do
          subject.approvals_required = described_class::APPROVALS_REQUIRED_MAX

          expect(subject).to be_valid
        end
      end

      context 'with rule_type set to report_approver' do
        before do
          subject.rule_type = :report_approver
        end

        it 'is invalid' do
          subject.report_type = nil
          expect(subject).not_to be_valid
        end
      end

      context 'when importing' do
        before do
          subject.importing = true
        end

        context 'when orchestration_policy_idx is not nil' do
          it 'is invalid' do
            subject.orchestration_policy_idx = 2

            expect(subject).to be_invalid
            expect(subject.errors.key?(:orchestration_policy_idx)).to be(true)
          end
        end

        context 'when orchestration_policy_idx is nil' do
          it 'is valid' do
            subject.orchestration_policy_idx = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is nil' do
          it 'is valid' do
            subject.report_type = nil

            expect(subject).to be_valid
          end
        end

        context 'when report type is scan_finding' do
          it 'is invalid' do
            subject.report_type = :scan_finding

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is license_scanning' do
          it 'is invalid' do
            subject.report_type = :license_scanning

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is any_merge_request' do
          it 'is invalid' do
            subject.report_type = :any_merge_request

            expect(subject).to be_invalid
            expect(subject.errors).to have_key(:report_type)
          end
        end

        context 'when report type is code_coverage' do
          it 'is valid' do
            subject.report_type = :code_coverage
            subject.name = 'Coverage-Check'

            expect(subject).to be_valid
          end
        end
      end

      context 'name attribute' do
        it { is_expected.to validate_length_of(:name).is_at_most(described_class::NAME_LENGTH_LIMIT) }

        context 'when name is above the length limit' do
          it 'does not cause a validation error when the name is not changed' do
            # Modify the name in the database directly to bypass validations
            subject.class.where(id: subject.id).update_all(
              name: 'x' * (described_class::NAME_LENGTH_LIMIT + 10)
            )

            subject.reload
            expect(subject.name.length).to be > described_class::NAME_LENGTH_LIMIT

            subject.update!(approvals_required: described_class::APPROVALS_REQUIRED_MAX)
            expect(subject).to be_valid
          end
        end
      end
    end

    describe 'delegations' do
      it { is_expected.to delegate_method(:security_report_time_window).to(:approval_policy_source).allow_nil }
    end

    describe '#vulnerability_attributes' do
      let(:approval_policy_source) { instance_double(Security::ApprovalPolicySource) }

      before do
        allow(subject).to receive(:approval_policy_source).and_return(approval_policy_source)
      end

      it 'stringifies keys from the source' do
        allow(approval_policy_source).to receive(:vulnerability_attributes)
          .and_return(false_positive: true)

        expect(subject.vulnerability_attributes).to eq('false_positive' => true)
      end

      it 'returns nil when the source is nil' do
        allow(subject).to receive(:approval_policy_source).and_return(nil)

        expect(subject.vulnerability_attributes).to be_nil
      end

      it 'returns nil when the source returns nil' do
        allow(approval_policy_source).to receive(:vulnerability_attributes).and_return(nil)

        expect(subject.vulnerability_attributes).to be_nil
      end
    end
  end

  context 'MergeRequest' do
    subject { create(:approval_merge_request_rule, *subject_traits, merge_request: merge_request) }

    it_behaves_like 'approval rule like'

    describe('#approvers') do
      context 'when role_approvers exist for codeowner rule' do
        subject { create(:code_owner_rule, *subject_traits, merge_request: merge_request) }

        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project) }
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }
        let_it_be(:user3) { create(:user) }

        before_all do
          group.add_maintainer(user3)
          project.add_maintainer(user1)
          project.add_owner(user2)
        end

        before do
          subject.update!(role_approvers: [Gitlab::Access::MAINTAINER])
        end

        it 'contains role members' do
          rule = subject.class.find(subject.id)

          expect(rule.approvers).to contain_exactly(user1)
        end
      end
    end

    describe '#approvers_include_user?' do
      let(:rule) { subject.class.find(subject.id) }

      before do
        rule.update!(rule_type: 'code_owner', role_approvers: [Gitlab::Access::DEVELOPER])
        rule.project.add_developer(user1)
        rule.project.add_maintainer(user2)
      end

      it 'returns true for user within the selected roles' do
        expect(rule.approvers_include_user?(user1)).to be_truthy
      end

      it 'returns false for user not within the selected roles' do
        expect(rule.approvers_include_user?(user2)).to be_falsey
      end
    end

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end

      context 'when rule has source rule' do
        let(:source_rule) do
          create(
            :approval_project_rule,
            project: merge_request.target_project,
            name: 'Source Rule',
            approvals_required: 2,
            users: [user1, user2],
            groups: [group1, group2]
          )
        end

        before do
          subject.update!(approval_project_rule: source_rule)
        end

        context 'and any attributes differ from source rule' do
          shared_examples_for 'overridden rule' do
            it 'returns true' do
              expect(subject.overridden?).to be_truthy
            end
          end

          context 'name' do
            before do
              subject.update!(name: 'Overridden Rule')
            end

            it_behaves_like 'overridden rule'
          end

          context 'approvals_required' do
            before do
              subject.update!(approvals_required: 1)
            end

            it_behaves_like 'overridden rule'
          end

          context 'users' do
            before do
              subject.update!(users: [user1])
            end

            it_behaves_like 'overridden rule'
          end

          context 'groups' do
            before do
              subject.update!(groups: [group1])
            end

            it_behaves_like 'overridden rule'
          end
        end

        context 'and no changes made to attributes' do
          before do
            subject.update!(
              name: source_rule.name,
              approvals_required: source_rule.approvals_required,
              users: source_rule.users,
              groups: source_rule.groups
            )
          end

          it 'returns false' do
            expect(subject.overridden?).to be_falsy
          end
        end
      end
    end
  end

  context 'Project' do
    subject { create(:approval_project_rule, *subject_traits) }

    it_behaves_like 'approval rule like'

    describe '#overridden?' do
      it 'returns false' do
        expect(subject.overridden?).to be_falsy
      end
    end
  end

  describe '.group_users' do
    subject { create(:approval_project_rule) }

    it 'returns distinct users' do
      group1.add_guest(user1)
      group2.add_guest(user1)
      subject.groups = [group1, group2]

      expect(subject.group_users).to eq([user1])
    end
  end

  describe '.exportable' do
    let_it_be(:project) { create(:project) }

    let_it_be(:any_approver_rule) { create(:approval_project_rule, :any_approver_rule, project: project) }
    let_it_be(:license_scanning_rule) { create(:approval_project_rule, :license_scanning, project: project) }
    let_it_be(:code_coverage) { create(:approval_project_rule, :code_coverage, project: project) }
    let_it_be(:scan_finding) { create(:approval_project_rule, :scan_finding, project: project) }
    let_it_be(:any_merge_request) { create(:approval_project_rule, :any_merge_request, project: project) }

    subject { project.approval_rules.exportable }

    it 'does not include rules created from scan result policies' do
      is_expected.to match_array([any_approver_rule, code_coverage])
    end
  end

  describe '.for_approval_policy_rules' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_policy) { create(:security_policy) }
    let_it_be(:other_security_policy) { create(:security_policy) }
    let_it_be(:policy_rule1) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:policy_rule2) { create(:approval_policy_rule, security_policy: security_policy) }

    let_it_be(:approval_rule1) { create(:approval_project_rule, project: project, approval_policy_rule: policy_rule1) }
    let_it_be(:approval_rule2) { create(:approval_project_rule, project: project, approval_policy_rule: policy_rule2) }
    let_it_be(:approval_rule3) { create(:approval_project_rule, project: project, approval_policy_rule: nil) }

    it 'returns approval rules associated with the given policy rules' do
      result = project.approval_rules.for_approval_policy_rules(security_policy.approval_policy_rules)

      expect(result).to include(approval_rule1, approval_rule2)
      expect(result).not_to include(approval_rule3)
    end

    it 'returns empty when no matching policy rules exist' do
      result = project.approval_rules.for_approval_policy_rules(other_security_policy.approval_policy_rules)

      expect(result).to be_empty
    end

    it 'handles empty policy rules relation' do
      result = project.approval_rules.for_approval_policy_rules(Security::ApprovalPolicyRule.none)

      expect(result).to be_empty
    end

    it 'handles empty policy rules array' do
      result = project.approval_rules.for_approval_policy_rules([])

      expect(result).to be_empty
    end

    it 'returns approval rules associated with the given policy rules passed as array' do
      result = project.approval_rules.for_approval_policy_rules([policy_rule1, policy_rule2])

      expect(result).to include(approval_rule1, approval_rule2)
      expect(result).not_to include(approval_rule3)
    end
  end

  describe '.for_merge_requests' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:other_merge_request) { create(:merge_request) }

    let_it_be(:rule_1) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let_it_be(:rule_2) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let_it_be(:rule_3) { create(:approval_merge_request_rule, merge_request: build(:merge_request)) }

    it 'returns rules for the specified merge request' do
      result = ApprovalMergeRequestRule.for_merge_requests(merge_request.id)

      expect(result).to contain_exactly(rule_1, rule_2)
    end

    it 'returns empty when no rules match the merge request' do
      result = ApprovalMergeRequestRule.for_merge_requests(other_merge_request.id)

      expect(result).to be_empty
    end

    it 'supports multiple merge requests' do
      rule_4 = create(:approval_merge_request_rule, merge_request: other_merge_request)

      result = ApprovalMergeRequestRule.for_merge_requests([merge_request.id, other_merge_request.id])

      expect(result).to contain_exactly(rule_1, rule_2, rule_4)
    end
  end

  describe '#approval_policy_source' do
    let_it_be(:project) { create(:project, :small_repo) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

    let_it_be(:security_policy) do
      create(:security_policy, :approval_policy,
        security_orchestration_policy_configuration: policy_configuration,
        linked_projects: [project])
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
    end

    let_it_be(:scan_result_policy_read) do
      create(:scan_result_policy_read,
        project: project,
        security_orchestration_policy_configuration: policy_configuration)
    end

    context 'when approval_policy_rule is present' do
      let(:approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_id: scan_result_policy_read.id,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'returns an ApprovalPolicySource backed by approval_policy_rule' do
        source = approval_rule.approval_policy_source

        expect(source).to be_a(Security::ApprovalPolicySource)
        expect(source.approval_policy_rule_id).to eq(approval_policy_rule.id)
        expect(source.resolved_approval_policy_rule).to eq(approval_policy_rule)
      end
    end

    context 'when approval_policy_rule is nil but scan_result_policy_read is present' do
      let(:approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          scan_result_policy_id: scan_result_policy_read.id,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'falls back to scan_result_policy_read' do
        source = approval_rule.approval_policy_source

        expect(source).to be_a(Security::ApprovalPolicySource)
        expect(source.scan_result_policy_id).to eq(scan_result_policy_read.id)
        expect(source.approval_policy_rule_id).to be_nil
      end
    end

    context 'when both are nil' do
      let(:approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          security_orchestration_policy_configuration: policy_configuration)
      end

      it 'returns nil' do
        expect(approval_rule.approval_policy_source).to be_nil
      end
    end

    context 'when deprecate_scan_result_policies flag is disabled' do
      before do
        stub_feature_flags(deprecate_scan_result_policies: false)
      end

      context 'when scan_result_policy_read is present' do
        let(:approval_rule) do
          create(:approval_project_rule, :scan_finding,
            project: project,
            scan_result_policy_id: scan_result_policy_read.id,
            security_orchestration_policy_configuration: policy_configuration)
        end

        it 'returns an ApprovalPolicySource backed by scan_result_policy_read' do
          source = approval_rule.approval_policy_source

          expect(source).to be_a(Security::ApprovalPolicySource)
          expect(source.scan_result_policy_id).to eq(scan_result_policy_read.id)
          expect(source.resolved_approval_policy_rule)
            .to eq(scan_result_policy_read.approval_policy_rule)
        end
      end

      context 'when scan_result_policy_read is nil' do
        let(:approval_rule) do
          create(:approval_project_rule, :scan_finding,
            project: project,
            security_orchestration_policy_configuration: policy_configuration)
        end

        it 'returns nil' do
          expect(approval_rule.approval_policy_source).to be_nil
        end
      end
    end
  end

  # rubocop:enable RSpec/FactoryBot/AvoidCreate
end
