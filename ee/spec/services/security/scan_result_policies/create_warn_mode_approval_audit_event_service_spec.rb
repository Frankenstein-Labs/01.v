# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventService, '#execute', feature_category: :security_policy_management do
  let_it_be_with_reload(:project) do
    create(:project, merge_requests_author_approval: true, merge_requests_disable_committers_approval: false,
      require_password_to_approve: false)
  end

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let(:mr_reference) { merge_request.to_reference(full: true) }
  let_it_be(:user) { create(:user) }

  let(:warn_mode_policies) { [] }
  let(:enforced_policies) { [] }
  let(:committers) { [project.creator] }
  let(:commit_collection) { instance_double(CommitCollection, committers: committers) }
  let(:service) { described_class.new(merge_request, user) }

  subject(:execute) { Gitlab::SafeRequestStore.ensure_request_store { service.execute } }

  before do
    allow(merge_request).to receive(:commits).and_return(commit_collection)
  end

  shared_examples 'does not create audit events' do
    specify do
      expect { execute }.not_to change { AuditEventReader.count }.from(0)
    end
  end

  shared_examples 'creates audit events' do |expected_events|
    it 'creates audit events with expected details' do
      base_attributes = {
        event_name: described_class::AUDIT_EVENT,
        author_name: 'GitLab Security Policy Bot',
        author_class: 'User',
        target_type: 'MergeRequest',
        target_id: merge_request.id
      }

      expected_audit_details = expected_events.map do |event|
        policy_names = event[:policy_names].join(", ")
        full_message = "In merge request (#{mr_reference}), #{event[:message]} " \
          "which would have been prevented by the following security policies in warn mode: #{policy_names}"

        hash_including(base_attributes.merge(custom_message: full_message))
      end

      expect { execute }.to change { AuditEventReader.all.pluck(:details) }
        .from(be_empty)
        .to(match_array(expected_audit_details))
    end

    it 'associates audit events scope with correct policy management project ids' do
      execute

      policy_names = expected_events.pluck(:policy_names).flatten.uniq
      expected_project_ids = Security::Policy.where(name: policy_names).pluck(:security_policy_management_project_id)

      expect(AuditEventReader.all.map(&:entity_id)).to match_array(expected_project_ids)
    end
  end

  context 'with restrictive warn-mode policy' do
    describe 'prevent_approval_by_author' do
      let_it_be(:warn_mode_policy_a) do
        create_policy(name: "A", policy_index: 1, warn_mode: true,
          approval_settings: { prevent_approval_by_author: true })
      end

      let(:warn_mode_policies) { [warn_mode_policy_a] }

      before do
        setup_policies_with_violations(warn_mode_policies)
      end

      context 'when approver is not author' do
        include_examples 'does not create audit events'
      end

      context 'when approver is author' do
        let(:user) { merge_request.author }

        include_examples 'creates audit events', [
          { message: "The merge request author approved their own merge request", policy_names: ["A"] }
        ]

        context 'with enforced policy' do
          let_it_be(:enforced_policy_a) do
            create_policy(name: "AA", policy_index: 2, approval_settings: { prevent_approval_by_author: true })
          end

          let(:enforced_policies) { [enforced_policy_a] }

          before do
            setup_policies_with_violations(enforced_policies)
          end

          include_examples 'does not create audit events'
        end
      end
    end

    describe 'prevent_approval_by_commit_author' do
      let_it_be(:warn_mode_policy_b) do
        create_policy(name: "B", policy_index: 3, warn_mode: true,
          approval_settings: { prevent_approval_by_commit_author: true })
      end

      let(:warn_mode_policies) { [warn_mode_policy_b] }

      before do
        setup_policies_with_violations(warn_mode_policies)
      end

      context 'when approver has not committed' do
        include_examples 'does not create audit events'
      end

      context 'when approver has committed' do
        let(:committers) { [user] }

        include_examples 'creates audit events', [
          { message: "A user approved the merge request that they also committed to", policy_names: ["B"] }
        ]

        context 'with enforced policy' do
          let_it_be(:enforced_policy_b) do
            create_policy(name: "BB", policy_index: 4, approval_settings: { prevent_approval_by_commit_author: true })
          end

          let(:enforced_policies) { [enforced_policy_b] }

          before do
            setup_policies_with_violations(enforced_policies)
          end

          include_examples 'does not create audit events'
        end
      end
    end

    describe 'require_password_to_approve' do
      let_it_be(:warn_mode_policy_c) do
        create_policy(name: "C", policy_index: 5, warn_mode: true,
          approval_settings: { require_password_to_approve: true })
      end

      let(:warn_mode_policies) { [warn_mode_policy_c] }

      before do
        setup_policies_with_violations(warn_mode_policies)
      end

      context 'when project requires password approval' do
        before do
          project.update!(require_password_to_approve: true)
        end

        include_examples 'does not create audit events'
      end

      context 'when project does not require password approval' do
        include_examples 'creates audit events', [
          { message: "A user approved the merge request without reauthenticating", policy_names: ["C"] }
        ]

        context 'with enforced policy' do
          let_it_be(:enforced_policy_c) do
            create_policy(name: "CC", policy_index: 6, approval_settings: { require_password_to_approve: true })
          end

          let(:enforced_policies) { [enforced_policy_c] }

          before do
            setup_policies_with_violations(enforced_policies)
          end

          include_examples 'does not create audit events'
        end
      end
    end
  end

  context 'with multiple restrictive policies' do
    let_it_be(:warn_mode_policy_g) do
      create_policy(name: "G", policy_index: 7, warn_mode: true,
        approval_settings: { prevent_approval_by_author: true })
    end

    let_it_be(:warn_mode_policy_h) do
      create_policy(name: "H", policy_index: 8, warn_mode: true,
        approval_settings: { prevent_approval_by_author: true, prevent_approval_by_commit_author: true })
    end

    let(:user) { merge_request.author }
    let(:committers) { [user] }
    let(:warn_mode_policies) { [warn_mode_policy_g, warn_mode_policy_h] }

    before do
      setup_policies_with_violations(warn_mode_policies)
    end

    include_examples 'creates audit events', [
      { message: "A user approved the merge request that they also committed to", policy_names: ["H"] },
      { message: "The merge request author approved their own merge request", policy_names: %w[G H] }
    ]
  end

  context 'when policies belong to different policy_configurations' do
    let_it_be(:policy_configuration_i) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration_g) { create(:security_orchestration_policy_configuration) }

    let_it_be(:warn_mode_policy_i) do
      create_policy(name: "I", policy_index: 9, warn_mode: true,
        configuration: policy_configuration_i,
        approval_settings: { prevent_approval_by_author: true })
    end

    let_it_be(:warn_mode_policy_j) do
      create_policy(name: "J", policy_index: 10, warn_mode: true,
        configuration: policy_configuration_g,
        approval_settings: { prevent_approval_by_commit_author: true })
    end

    let(:user) { merge_request.author }
    let(:committers) { [user] }

    let(:warn_mode_policies) { [warn_mode_policy_i, warn_mode_policy_j] }

    before do
      setup_policies_with_violations(warn_mode_policies)
    end

    include_examples 'creates audit events', [
      { message: "The merge request author approved their own merge request", policy_names: ["I"] },
      { message: "A user approved the merge request that they also committed to", policy_names: ["J"] }
    ]

    it 'does not cause N+1 queries' do
      allow(merge_request).to receive(:push_audit_event).and_return(true)

      execute

      control = ActiveRecord::QueryRecorder.new do
        Gitlab::SafeRequestStore.ensure_request_store do
          described_class.new(merge_request, user).execute
        end
      end

      policy_k = create_policy(name: "K", policy_index: 11, warn_mode: true,
        configuration: create(:security_orchestration_policy_configuration),
        approval_settings: { prevent_approval_by_author: true })
      policy_l = create_policy(name: "L", policy_index: 12, warn_mode: true,
        configuration: create(:security_orchestration_policy_configuration),
        approval_settings: { prevent_approval_by_commit_author: true })

      setup_policies_with_violations([policy_k, policy_l])

      expect do
        ActiveRecord::QueryRecorder.new do
          Gitlab::SafeRequestStore.ensure_request_store { described_class.new(merge_request, user).execute }
        end
      end.not_to exceed_query_limit(control)
    end
  end

  context 'without any policies' do
    it 'does not create security policy bot' do
      expect { execute }.not_to change { project.reload.security_policy_bot }.from(nil)
    end
  end

  private

  def create_policy(name:, policy_index:, approval_settings: {}, warn_mode: false, configuration: policy_configuration)
    enforcement_type = warn_mode ? Security::Policy::ENFORCEMENT_TYPE_WARN : Security::Policy::DEFAULT_ENFORCEMENT_TYPE

    create(:security_policy,
      name: name,
      security_orchestration_policy_configuration: configuration,
      policy_index: policy_index,
      content: { approval_settings: approval_settings, enforcement_type: enforcement_type }
    )
  end

  def setup_policies_with_violations(policies)
    policies.each do |policy|
      policy_read = create_policy_read(policy)
      approval_rule = create(:approval_policy_rule, security_policy: policy)
      create_violation(policy_read, approval_rule)
    end
  end

  def create_policy_read(policy)
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy.security_orchestration_policy_configuration)
  end

  def create_violation(policy, approval_rule, data = {})
    create(:scan_result_policy_violation, :failed,
      project: project,
      merge_request: merge_request,
      scan_result_policy_read: policy,
      approval_policy_rule: approval_rule,
      violation_data: data
    )
  end
end
