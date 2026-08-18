# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Checks::PushRuleCheck, feature_category: :source_code_management do
  include_context 'changes access checks context'

  subject(:push_rule_check) { described_class.new(changes_access) }

  let(:push_rule) { create(:push_rule, :commit_message) }
  let(:project) { create(:project, :public, :repository, push_rule: push_rule) }

  before do
    allow(project.repository).to receive(:new_commits).and_return(
      project.repository.commits_between('be93687618e4b132087f430a4d8fc3a609c9b77c', '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51')
    )
  end

  describe '#validate!' do
    before do
      allow_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
        .to receive(:validate!).and_return(nil)
      allow_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
        .to receive(:validate!).and_return(nil)

      allow(project).to receive(:jira_integration).and_return(nil)

      allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
        .to receive(:validate!).and_return(nil)
    end

    it "returns nil on success" do
      expect(push_rule_check.validate!).to be_nil
    end

    context 'when tag name exists' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/name' }
        ]
      end

      it 'validates tags push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .not_to receive(:validate!)

        push_rule_check.validate!
      end
    end

    context 'when branch name exists' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/name' }
        ]
      end

      it 'validates branches push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .not_to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .to receive(:validate!)

        push_rule_check.validate!
      end
    end

    context 'when changes are from notes ref' do
      let(:changes) do
        [{ oldrev: oldrev, newrev: newrev, ref: 'refs/notes/commits' }]
      end

      it 'does not validate push rules for tags or branches' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck).not_to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck).not_to receive(:validate!)

        push_rule_check.validate!
      end
    end

    context 'when tag and branch exist' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/name' },
          { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/name' }
        ]
      end

      it 'validates tag and branch push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .to receive(:validate!)

        push_rule_check.validate!
      end
    end

    context 'when Jira verification is needed' do
      before do
        allow_any_instance_of(described_class)
          .to receive(:push_rule).and_return(nil)

        jira_integration = instance_double(Integrations::Jira, present?: true)
        allow(project).to receive(:jira_integration).and_return(jira_integration)
      end

      it 'calls JiraVerificationCheck once with changes_access' do
        expect_next_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck, changes_access) do |instance|
          expect(instance).to receive(:validate!)
        end

        push_rule_check.validate!
      end

      it 'creates JiraVerificationCheck instance with correct parameters' do
        expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
          .to receive(:new).once.with(changes_access).and_call_original

        allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
          .to receive(:validate!)

        push_rule_check.validate!
      end

      context 'when JiraVerificationCheck raises an error' do
        it 'stops execution and propagates the error' do
          allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:validate!).and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")

          expect { push_rule_check.validate! }
            .to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")
        end
      end

      context 'with different types of changes' do
        let(:changes) do
          [
            { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/feature-branch' },
            { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/v1.0.0' },
            { newrev: newrev, ref: 'refs/heads/new-branch' },
            { oldrev: oldrev, ref: 'refs/heads/deleted-branch' }
          ]
        end

        it 'processes all change types through Jira verification' do
          expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:new).once.with(changes_access).and_call_original

          allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:validate!)

          push_rule_check.validate!
        end
      end
    end
  end

  describe '#check_jira_verification!' do
    let(:jira_check) { instance_double(Gitlab::Checks::PushRules::JiraVerificationCheck) }

    it 'creates single JiraVerificationCheck with changes_access and calls validate!' do
      expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
        .to receive(:new).with(changes_access).and_return(jira_check)

      expect(jira_check).to receive(:validate!)

      push_rule_check.send(:check_jira_verification!)
    end

    context 'when validate! raises an exception' do
      before do
        allow(::Gitlab::Checks::PushRules::JiraVerificationCheck)
          .to receive(:new).with(changes_access).and_return(jira_check)
        allow(jira_check).to receive(:validate!)
          .and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira issue not found")
      end

      it 'propagates the exception' do
        expect { push_rule_check.send(:check_jira_verification!) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira issue not found")
      end
    end
  end
end
