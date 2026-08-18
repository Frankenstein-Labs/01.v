# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::AnnotatePolicyYamlService, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user, username: 'test_user') }
  let_it_be(:other_user) { create(:user, :private_profile, username: 'other_user') }

  let_it_be_with_reload(:org_group) { create(:group, :public, path: 'test_gitlab_org') }
  let_it_be_with_reload(:test_project) { create(:project, :public, group: org_group, path: 'test_project') }
  let_it_be(:security_private_group) { create(:group, :private, parent: org_group, path: 'security_private_group') }
  let_it_be(:security_project) { create(:project, group: security_private_group, path: 'security_project') }

  let_it_be(:other_group) { create(:group, :private, path: 'other_group') }
  let_it_be(:role) { create(:member_role, :instance, name: 'CustomRoleName') }

  let(:service) { described_class.new(user, policy_yaml) }

  describe '#execute' do
    subject(:result) { service.execute }

    shared_examples 'annotating the yaml' do
      it 'returns the annotated the yaml' do
        expect(result[:status]).to eq(:success)
        expect(result[:annotated_yaml]).to eq(expected_yaml)
      end
    end

    shared_examples 'not annotating the yaml' do
      it 'returns the original yaml' do
        expect(result[:status]).to eq(:success)
        expect(result[:annotated_yaml]).to eq(policy_yaml)
      end
    end

    context 'when policy_yaml contains user_approvers_ids' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Test Policy
          actions:
          - type: require_approval
            user_approvers_ids:
              - #{user.id}
              - #{other_user.id}
              - 999
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Test Policy
          actions:
          - type: require_approval
            user_approvers_ids:
              - #{user.id} # test_user
              - #{other_user.id} # other_user
              - 999 # not_found
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when policy_yaml contains skip_ci user ids' do
      let(:policy_yaml) do
        <<~YAML
          scan_execution_policy:
          - name: Project Policy
            policy_scope:
              projects:
                including:
                  - id: #{test_project.id}
            skip_ci:
              allowed: false
              allowlist:
                users:
                  - id: #{user.id}
                  - id: #{other_user.id}
                  - id: 1234
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        scan_execution_policy:
        - name: Project Policy
          policy_scope:
            projects:
              including:
                - id: #{test_project.id} # test_gitlab_org/test_project
          skip_ci:
            allowed: false
            allowlist:
              users:
                - id: #{user.id} # test_user
                - id: #{other_user.id} # other_user
                - id: 1234 # not_found
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when policy_yaml contains group_approvers_ids and group ids' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Group Policy
          policy_scope:
            groups:
              excluding:
                - id: #{org_group.id}
                - id: #{other_group.id}
          actions:
          - type: require_approval
            group_approvers_ids:
              - #{security_private_group.id}
              - 12345
        YAML
      end

      # security_private_group is annotated depending on the user's access
      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Group Policy
          policy_scope:
            groups:
              excluding:
                - id: #{org_group.id} # test_gitlab_org
                - id: #{other_group.id} # not_found
          actions:
          - type: require_approval
            group_approvers_ids:
              - #{security_private_group.id} # #{annotation_string}
              - 12345 # not_found
        YAML
      end

      context 'when the user is authorized to view the group' do
        before_all do
          security_private_group.add_developer(user)
        end

        let(:annotation_string) { 'test_gitlab_org/security_private_group' }

        it_behaves_like 'annotating the yaml'
      end

      context 'when the user is not authorized to view the group' do
        let(:annotation_string) { described_class::NOT_FOUND_STRING }

        it_behaves_like 'annotating the yaml'
      end
    end

    context 'when policy_yaml contains compliance_framework ids' do
      let_it_be(:test_framework) { create(:compliance_framework, namespace: org_group, name: 'GDPR') }

      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Framework Policy
          policy_scope:
            compliance_frameworks:
              including:
                - id: #{test_framework.id}
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Framework Policy
          policy_scope:
            compliance_frameworks:
              including:
                - id: #{test_framework.id} # #{annotation_string}
        YAML
      end

      before do
        stub_licensed_features(custom_compliance_frameworks: true)
      end

      context 'when the user is authorized to read the compliance framework' do
        let(:annotation_string) { 'GDPR' }

        it_behaves_like 'annotating the yaml'
      end

      context 'when the user is not authorized to read the compliance framework' do
        before do
          test_project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          org_group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
        end

        let(:annotation_string) { described_class::NOT_FOUND_STRING }

        it_behaves_like 'annotating the yaml'
      end
    end

    context 'when policy_yaml contains block_group_branch_modification ids' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Group Policy
          approval_settings:
            block_branch_modification: false
            block_group_branch_modification:
              enabled: true
              exceptions:
                - id: #{org_group.id}
          fallback_behavior:
            fail: open
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Group Policy
          approval_settings:
            block_branch_modification: false
            block_group_branch_modification:
              enabled: true
              exceptions:
                - id: #{org_group.id} # test_gitlab_org
          fallback_behavior:
            fail: open
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when policy_yaml contains project ids' do
      let(:policy_yaml) do
        <<~YAML
        scan_execution_policy:
        - name: Project Policy
          policy_scope:
            projects:
              including:
                - id: #{test_project.id}
                - id: #{security_project.id}
                - id: 999
        YAML
      end

      # security_project is annotated depending on the user's access
      let(:expected_yaml) do
        <<~YAML
        scan_execution_policy:
        - name: Project Policy
          policy_scope:
            projects:
              including:
                - id: #{test_project.id} # test_gitlab_org/test_project
                - id: #{security_project.id} # #{annotation_string}
                - id: 999 # not_found
        YAML
      end

      context 'when the user is authorized to view the project' do
        before_all do
          security_project.add_developer(user)
        end

        let(:annotation_string) { 'test_gitlab_org/security_private_group/security_project' }

        it_behaves_like 'annotating the yaml'
      end

      context 'when the user is not authorized to view the project' do
        let(:annotation_string) { described_class::NOT_FOUND_STRING }

        it_behaves_like 'annotating the yaml'
      end
    end

    context 'when policy_yaml contains custom role_approvers ids' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Role Policy
          actions:
          - type: require_approval
            approvals_required: 1
            role_approvers:
              - owner
              - #{role.id}
              - maintainer
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Role Policy
          actions:
          - type: require_approval
            approvals_required: 1
            role_approvers:
              - owner
              - #{role.id} # #{annotation_string}
              - maintainer
        YAML
      end

      context 'when the user is authorized to read the role' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        let(:annotation_string) { 'CustomRoleName' }

        it_behaves_like 'annotating the yaml'
      end

      context 'when the user is not authorized to read the role' do
        let(:annotation_string) { described_class::NOT_FOUND_STRING }

        it_behaves_like 'annotating the yaml'
      end
    end

    context 'when policy_yaml contains multiple fields' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Mixed Policy
          policy_scope:
            groups:
              including:
                - id: #{security_private_group.id}
                - id: 111
            projects:
              excluding:
                - id: #{test_project.id}
                - id: 111
          actions:
          - type: require_approval
            approvals_required: 1
            role_approvers:
            - owner
            - #{role.id} # CustomRoleName
            - maintainer
          - type: require_approval
            approvals_required: 1
            group_approvers_ids:
            - #{security_private_group.id} # test_gitlab_org/security_private_group
            user_approvers_ids:
            - #{user.id} # test_user
          approval_settings:
            block_branch_modification: false
            block_group_branch_modification:
              enabled: true
              exceptions:
                - id: #{other_group.id}
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Mixed Policy
          policy_scope:
            groups:
              including:
                - id: #{security_private_group.id} # test_gitlab_org/security_private_group
                - id: 111 # not_found
            projects:
              excluding:
                - id: #{test_project.id} # test_gitlab_org/test_project
                - id: 111 # not_found
          actions:
          - type: require_approval
            approvals_required: 1
            role_approvers:
            - owner
            - #{role.id} # CustomRoleName
            - maintainer
          - type: require_approval
            approvals_required: 1
            group_approvers_ids:
            - #{security_private_group.id} # test_gitlab_org/security_private_group
            user_approvers_ids:
            - #{user.id} # test_user
          approval_settings:
            block_branch_modification: false
            block_group_branch_modification:
              enabled: true
              exceptions:
                - id: #{other_group.id} # not_found
        YAML
      end

      before_all do
        security_private_group.add_developer(user)
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when policy_yaml contains an unrecognized field in the same level as the IDs' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Unrecognized Policy
          actions:
          - type: require_approval
            user_approvers_ids:
            - #{user.id}
            unrecognized_field:
            - 123
            group_approvers_ids:
            - #{org_group.id}
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Unrecognized Policy
          actions:
          - type: require_approval
            user_approvers_ids:
            - #{user.id} # test_user
            unrecognized_field:
            - 123
            group_approvers_ids:
            - #{org_group.id} # test_gitlab_org
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when policy_yaml has no annotable IDs' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: No IDs Policy
          description: A policy without any approver IDs.
          enabled: true
          rules:
          - type: schedule
            cadence: '*/15 * * * *'
        YAML
      end

      it_behaves_like 'not annotating the yaml'
    end

    context 'when policy_yaml is empty' do
      let(:policy_yaml) { '' }

      it_behaves_like 'not annotating the yaml'
    end

    context 'when policy_yaml has IDs but they are not in a list format' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Malformed Policy
          actions:
          - type: require_approval
            user_approvers_ids: user.id # Not a list item
        YAML
      end

      it_behaves_like 'not annotating the yaml'
    end

    context 'when policy_yaml contains non-numeric IDs' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Non-numeric Policy
          actions:
          - type: require_approval
            user_approvers_ids:
              - abc
              - #{user.id}
        YAML
      end

      let(:expected_yaml) do
        <<~YAML
        approval_policy:
        - name: Non-numeric Policy
          actions:
          - type: require_approval
            user_approvers_ids:
              - abc
              - #{user.id} # test_user
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when an ID list is empty' do
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Empty List Policy
          actions:
          policy_scope:
            groups:
              excluding: []
        YAML
      end

      it_behaves_like 'not annotating the yaml'
    end

    context 'with different indentation levels' do
      let(:policy_yaml) do
        <<~YAML
        policies:
          - type: approval_policy
            name: Indented Policy
            actions:
              - type: require_approval
                user_approvers_ids:
                                   - #{user.id}
            approval_settings:
              block_branch_modification: false
        YAML
      end

      # annotates preserving the indentation
      let(:expected_yaml) do
        <<~YAML
        policies:
          - type: approval_policy
            name: Indented Policy
            actions:
              - type: require_approval
                user_approvers_ids:
                                   - #{user.id} # test_user
            approval_settings:
              block_branch_modification: false
        YAML
      end

      it_behaves_like 'annotating the yaml'
    end

    context 'when there is an unexpected error' do
      let(:exception) { StandardError.new('unexpected error') }
      let(:policy_yaml) do
        <<~YAML
        approval_policy:
        - name: Framework Policy
          policy_scope:
            compliance_frameworks:
              including:
                - id: 777
        YAML
      end

      before do
        allow(::ComplianceManagement::FrameworksFinder).to receive(:new).and_raise(exception)
      end

      it 'wraps StandardError in a ServiceResponse' do
        response = service.execute

        expect(response[:status]).to eq(:error)
        expect(response[:message]).to eq('Unexpected error while annotating policy YAML')
        expect(response[:exception]).to eq(exception)
      end

      it 'tracks the error in Gitlab Error Tracking' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          exception, policy_yaml: policy_yaml
        ).and_call_original

        service.execute
      end
    end
  end
end
