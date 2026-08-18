# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::PushRules::JiraVerificationCheck, feature_category: :source_code_management do
  include_context 'changes access checks context'

  let(:push_rule) { create(:push_rule) }
  let(:jira_integration) { instance_double(Integrations::Jira) }
  let(:jira_data_fields) { instance_double(Integrations::JiraTrackerData) }
  # rubocop:disable RSpec/VerifiedDoubles -- Commit methods are delegated via method_missing
  let(:commit) { double('commit') }
  let(:jira_issue) { double('jira_issue') }
  let(:jira_assignee) { double('jira_assignee') }
  let(:jira_status) { double('jira_status') }
  # rubocop:enable RSpec/VerifiedDoubles

  before do
    # Setup basic commit properties
    allow(commit).to receive_messages(safe_message: 'Fix issue ABC-123', author_email: 'user@example.com',
      author_name: 'Test User', id: 'commit_sha')
  end

  describe '#validate!' do
    subject(:checker) { described_class.new(changes_access) }

    shared_context 'with a single commit lacking a Jira reference' do |message: 'Initial commit', id: 'abc123'|
      let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }
      # rubocop:disable RSpec/VerifiedDoubles -- Commit delegates to Gitlab::Git::Commit via method_missing
      let(:commit) { double('commit') }
      # rubocop:enable RSpec/VerifiedDoubles

      before do
        allow(commit).to receive_messages(safe_message: message, id: id)
        allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
        allow(single_change_access).to receive(:commits).and_return([commit])
        allow(checker).to receive(:any_jira_check_enabled?).and_return(true)
        allow(checker).to receive(:extract_jira_issue_keys).with(message).and_return([])
      end
    end

    context 'when the project repository is empty' do
      let_it_be(:project) { create(:project, :empty_repo) }

      before_all do
        project.add_developer(user)
      end

      before do
        allow(checker).to receive(:jira_enabled?).and_return(true)
      end

      context 'when the push originates from the web protocol' do
        let(:protocol) { 'web' }

        it 'skips Jira verification without raising an error' do
          expect { checker.validate! }.not_to raise_error
        end
      end

      context 'when the push originates from SSH' do
        let(:protocol) { 'ssh' }

        include_context 'with a single commit lacking a Jira reference'

        it 'enforces Jira verification and rejects the commit' do
          expect { checker.validate! }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'No Jira issue found in commit message'
          )
        end
      end
    end

    context 'when the project repository is NOT empty and push is from web' do
      let(:protocol) { 'web' }

      include_context 'with a single commit lacking a Jira reference', message: 'A change without Jira ref',
        id: 'def456'

      before do
        allow(checker).to receive(:jira_enabled?).and_return(true)
      end

      it 'enforces Jira verification and rejects the commit' do
        expect { checker.validate! }.to raise_error(
          Gitlab::GitAccess::ForbiddenError,
          'No Jira issue found in commit message'
        )
      end
    end

    context 'when Jira is not enabled' do
      before do
        allow(checker).to receive(:jira_enabled?).and_return(false)
      end

      it 'returns early without performing any checks' do
        expect(checker).not_to receive(:jira_verification_check)
        expect { checker.validate! }.not_to raise_error
      end
    end

    context 'when Jira is enabled' do
      before do
        allow(checker).to receive_messages(jira_enabled?: true, jira_integration: jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when no Jira checks are enabled' do
        before do
          allow(checker).to receive(:any_jira_check_enabled?).and_return(false)
        end

        it 'returns early without performing verification' do
          expect(checker).not_to receive(:extract_jira_issue_keys)
          expect { checker.validate! }.not_to raise_error
        end
      end

      context 'when Jira checks are enabled' do
        before do
          allow(checker).to receive_messages(any_jira_check_enabled?: true, extract_jira_issue_keys: ['ABC-123'])
        end

        context 'with successful validation' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: true,
              jira_assignee_check_enabled?: false, jira_status_check_enabled?: false)
          end

          it 'completes without raising an error' do
            expect { checker.validate! }.not_to raise_error
          end

          it 'processes each single change access' do
            expect(checker).to receive(:validate_single_change_access).with(single_change_access)
            checker.validate!
          end
        end

        context 'when no Jira issue found in commit message' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive(:extract_jira_issue_keys).and_return([])
          end

          it 'raises ForbiddenError' do
            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'No Jira issue found in commit message'
            )
          end
        end

        context 'when Jira issue does not exist' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(find_jira_issue: nil, jira_exists_check_enabled?: true,
              extract_jira_issue_keys: ['ABC-123'])
          end

          it 'raises ForbiddenError' do
            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'Jira issue ABC-123 does not exist'
            )
          end
        end

        context 'when assignee check fails' do
          # rubocop:disable RSpec/VerifiedDoubles -- JIRA gem classes are external
          let(:different_assignee) { double('different_assignee') }
          # rubocop:enable RSpec/VerifiedDoubles
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true, jira_status_check_enabled?: false,
              extract_jira_issue_keys: ['ABC-123'])
            allow(jira_issue).to receive_messages(present?: true, assignee: different_assignee, key: 'ABC-123')
            allow(different_assignee).to receive_messages(emailAddress: 'other@example.com', displayName: 'Other User',
              respond_to?: true, empty?: false)
          end

          it 'raises ForbiddenError when assignee does not match' do
            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'Jira issue ABC-123 is not assigned to you. It is assigned to Other User'
            )
          end
        end

        context 'when assignee check passes' do
          before do
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true, jira_status_check_enabled?: false)
            allow(jira_issue).to receive_messages(present?: true, assignee: jira_assignee)
            allow(jira_assignee).to receive_messages(emailAddress: 'user@example.com', displayName: 'Test User',
              respond_to?: true, empty?: false)
          end

          it 'does not raise an error when assignee email matches' do
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when assignee check passes by name' do
          before do
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true, jira_status_check_enabled?: false)
            allow(jira_issue).to receive_messages(present?: true, assignee: jira_assignee)
            allow(jira_assignee).to receive_messages(emailAddress: 'different@example.com', displayName: 'Test User',
              respond_to?: true, empty?: false)
          end

          it 'does not raise an error when assignee name matches' do
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when issue is not assigned' do
          before do
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true, jira_status_check_enabled?: false)
            allow(jira_issue).to receive_messages(present?: true, assignee: nil)
          end

          it 'does not raise an error' do
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when status check fails' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allowed_statuses = ['In Progress', 'Done']
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false, jira_status_check_enabled?: true,
              jira_allowed_statuses: allowed_statuses, extract_jira_issue_keys: ['ABC-123'])
            allow(jira_issue).to receive_messages(present?: true, status: jira_status, key: 'ABC-123')
            allow(jira_status).to receive(:name).and_return('To Do')
          end

          it 'raises ForbiddenError when status is not allowed' do
            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              "Jira issue ABC-123 has status 'To Do', which is not in the list of allowed statuses: In Progress, Done"
            )
          end
        end

        context 'when status check passes' do
          before do
            allowed_statuses = ['In Progress', 'Done']
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false, jira_status_check_enabled?: true,
              jira_allowed_statuses: allowed_statuses)
            allow(jira_issue).to receive_messages(present?: true, status: jira_status)
            allow(jira_status).to receive(:name).and_return('In Progress')
          end

          it 'does not raise an error when status is allowed' do
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when no allowed statuses are configured' do
          before do
            allow(checker).to receive_messages(find_jira_issue: jira_issue, jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false, jira_status_check_enabled?: true, jira_allowed_statuses: [])
            allow(jira_issue).to receive_messages(present?: true, status: jira_status)
            allow(jira_status).to receive(:name).and_return('Any Status')
          end

          it 'does not raise an error' do
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when Jira connection fails' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(extract_jira_issue_keys: ['ABC-123'])
            allow(checker).to receive(:find_jira_issue).and_raise(StandardError.new('Connection timeout'))
          end

          it 'raises ForbiddenError with connection error message' do
            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'Connection timeout'
            )
          end
        end
      end

      context 'when processing multiple commits' do
        # rubocop:disable RSpec/VerifiedDoubles -- Commit methods are delegated via method_missing
        let(:commit2) { double('commit2') }
        let(:commit3) { double('commit3') }
        # rubocop:enable RSpec/VerifiedDoubles

        before do
          allow(commit2).to receive_messages(safe_message: 'Fix issue DEF-456', author_email: 'user2@example.com',
            author_name: 'Test User 2', id: 'commit_sha2')
          allow(commit3).to receive_messages(safe_message: 'Fix issue GHI-789', author_email: 'user3@example.com',
            author_name: 'Test User 3', id: 'commit_sha3')
        end

        context 'with all commits passing validation' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit, commit2, commit3])
            allow(checker).to receive(:extract_jira_issue_keys).and_return(['ABC-123'], ['DEF-456'], ['GHI-789'])
            allow(checker).to receive_messages(any_jira_check_enabled?: true,
              find_jira_issue: jira_issue, jira_exists_check_enabled?: true, jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: false)
          end

          it 'processes all commits in order' do
            expect(checker).to receive(:jira_verification_check).with(commit).ordered
            expect(checker).to receive(:jira_verification_check).with(commit2).ordered
            expect(checker).to receive(:jira_verification_check).with(commit3).ordered
            checker.validate!
          end

          it 'iterates through each commit with index' do
            call_order = []
            allow(checker).to receive(:jira_verification_check) do |commit_arg|
              call_order << commit_arg.id
            end

            checker.validate!
            expect(call_order).to eq(%w[commit_sha commit_sha2 commit_sha3])
          end
        end

        context 'when first commit fails validation' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit, commit2])
            allow(checker).to receive_messages(any_jira_check_enabled?: true)
            allow(checker).to receive(:extract_jira_issue_keys).and_return([])
          end

          it 'stops processing on first error and does not process remaining commits' do
            expect(checker).to receive(:jira_verification_check).with(commit).and_raise(
              Gitlab::GitAccess::ForbiddenError.new('No Jira issue found in commit message')
            )
            expect(checker).not_to receive(:jira_verification_check).with(commit2)

            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'No Jira issue found in commit message'
            )
          end
        end

        context 'when middle commit fails validation' do
          # rubocop:disable RSpec/VerifiedDoubles -- Commit methods are delegated via method_missing
          let(:failing_commit) { double('failing_commit') }
          # rubocop:enable RSpec/VerifiedDoubles
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(failing_commit).to receive_messages(safe_message: 'No Jira issue', author_email: 'user@example.com',
              author_name: 'Test User', id: 'failing_commit_sha')
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit, failing_commit, commit2])
            allow(checker).to receive_messages(any_jira_check_enabled?: true)

            # First commit succeeds
            allow(checker).to receive(:extract_jira_issue_keys).with('Fix issue ABC-123').and_return(['ABC-123'])
            allow(checker).to receive(:find_jira_issue).with('ABC-123').and_return(jira_issue)
            allow(checker).to receive_messages(jira_exists_check_enabled?: true, jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: false)

            # Second commit fails (no Jira issue)
            allow(checker).to receive(:extract_jira_issue_keys).with('No Jira issue').and_return([])
          end

          it 'processes commits until failure and stops' do
            expect(checker).to receive(:jira_verification_check).with(commit).and_call_original
            expect(checker).to receive(:jira_verification_check).with(failing_commit).and_call_original
            expect(checker).not_to receive(:jira_verification_check).with(commit2)

            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'No Jira issue found in commit message'
            )
          end
        end

        context 'with mixed commit scenarios' do
          # rubocop:disable RSpec/VerifiedDoubles -- Commit methods are delegated via method_missing
          let(:no_jira_commit) { double('no_jira_commit') }
          let(:valid_jira_commit) { double('valid_jira_commit') }
          # rubocop:enable RSpec/VerifiedDoubles
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(no_jira_commit).to receive_messages(safe_message: 'Regular commit without Jira',
              author_email: 'user@example.com', author_name: 'Test User', id: 'no_jira_sha')
            allow(valid_jira_commit).to receive_messages(safe_message: 'Fix issue XYZ-999',
              author_email: 'user@example.com', author_name: 'Test User', id: 'valid_jira_sha')

            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([valid_jira_commit, no_jira_commit])
            allow(checker).to receive_messages(any_jira_check_enabled?: true)

            # First commit has valid Jira issue
            allow(checker).to receive(:extract_jira_issue_keys).with('Fix issue XYZ-999').and_return(['XYZ-999'])
            allow(checker).to receive(:find_jira_issue).with('XYZ-999').and_return(jira_issue)
            allow(checker).to receive_messages(jira_exists_check_enabled?: true, jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: false)

            # Second commit has no Jira issue
            allow(checker).to receive(:extract_jira_issue_keys).with('Regular commit without Jira').and_return([])
          end

          it 'validates first commit then fails on second commit' do
            expect(checker).to receive(:jira_verification_check).with(valid_jira_commit).and_call_original
            expect(checker).to receive(:jira_verification_check).with(no_jira_commit).and_call_original

            expect { checker.validate! }.to raise_error(
              Gitlab::GitAccess::ForbiddenError,
              'No Jira issue found in commit message'
            )
          end
        end

        context 'when commits array is empty' do
          before do
            allow(checker).to receive(:commits).and_return([])
          end

          it 'does not call jira_verification_check and completes successfully' do
            expect(checker).not_to receive(:jira_verification_check)
            expect { checker.validate! }.not_to raise_error
          end
        end

        context 'when commits array has single commit' do
          let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

          before do
            allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
            allow(single_change_access).to receive(:commits).and_return([commit])
            allow(checker).to receive_messages(any_jira_check_enabled?: true,
              extract_jira_issue_keys: ['ABC-123'], find_jira_issue: jira_issue,
              jira_exists_check_enabled?: true, jira_assignee_check_enabled?: false, jira_status_check_enabled?: false)
          end

          it 'processes the single commit correctly' do
            expect(checker).to receive(:jira_verification_check).with(commit).once
            checker.validate!
          end
        end
      end

      context 'when an unexpected error occurs during validation' do
        let(:single_change_access) { instance_double(Gitlab::Checks::SingleChangeAccess) }

        before do
          allow(changes_access).to receive(:single_change_accesses).and_return([single_change_access])
          allow(single_change_access).to receive(:commits).and_return([commit])
          allow(checker).to receive(:jira_verification_check).and_raise(RuntimeError.new('Unexpected error'))
        end

        it 'wraps the error in ForbiddenError' do
          expect { checker.validate! }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'Unexpected error'
          )
        end
      end
    end
  end

  describe '#jira_enabled?' do
    subject(:checker) { described_class.new(changes_access) }

    context 'when no Jira integration exists' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns false' do
        expect(checker.send(:jira_enabled?)).to be false
      end
    end

    context 'when Jira integration exists but is not activated' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:activated?).and_return(false)
      end

      it 'returns false' do
        expect(checker.send(:jira_enabled?)).to be false
      end

      it 'does not call jira_check_enabled? when integration is not activated' do
        expect(checker).not_to receive(:jira_check_enabled?)
        checker.send(:jira_enabled?)
      end
    end

    context 'when Jira integration is activated but check is disabled' do
      before do
        allow(jira_integration).to receive(:activated?).and_return(true)
        allow(checker).to receive_messages(jira_integration: jira_integration, jira_check_enabled?: false)
      end

      it 'returns false' do
        expect(checker.send(:jira_enabled?)).to be false
      end

      it 'calls both activated? and jira_check_enabled?' do
        expect(jira_integration).to receive(:activated?).and_return(true)
        expect(checker).to receive(:jira_check_enabled?).and_return(false)
        expect(checker.send(:jira_enabled?)).to be false
      end
    end

    context 'when Jira integration is activated and check is enabled' do
      before do
        allow(jira_integration).to receive(:activated?).and_return(true)
        allow(checker).to receive_messages(jira_integration: jira_integration, jira_check_enabled?: true)
      end

      it 'returns true' do
        expect(checker.send(:jira_enabled?)).to be true
      end

      it 'calls both activated? and jira_check_enabled?' do
        expect(jira_integration).to receive(:activated?).and_return(true)
        expect(checker).to receive(:jira_check_enabled?).and_return(true)
        expect(checker.send(:jira_enabled?)).to be true
      end
    end

    context 'when integration is activated but jira_check_enabled? returns nil' do
      before do
        allow(jira_integration).to receive(:activated?).and_return(true)
        allow(checker).to receive_messages(jira_integration: jira_integration, jira_check_enabled?: nil)
      end

      it 'returns nil due to falsy jira_check_enabled?' do
        expect(checker.send(:jira_enabled?)).to be_nil
      end

      it 'evaluates the full boolean expression' do
        expect(jira_integration).to receive(:activated?).and_return(true)
        expect(checker).to receive(:jira_check_enabled?).and_return(nil)
        expect(checker.send(:jira_enabled?)).to be_nil
      end
    end

    context 'when integration activated? returns false and jira_check_enabled? would return true' do
      before do
        allow(jira_integration).to receive(:activated?).and_return(false)
        allow(checker).to receive_messages(jira_integration: jira_integration, jira_check_enabled?: true)
      end

      it 'returns false due to short-circuit evaluation' do
        expect(checker.send(:jira_enabled?)).to be false
      end

      it 'does not call jira_check_enabled? due to short-circuit evaluation' do
        expect(jira_integration).to receive(:activated?).and_return(false)
        expect(checker).not_to receive(:jira_check_enabled?)
        expect(checker.send(:jira_enabled?)).to be false
      end
    end
  end

  describe '#jira_verification_check' do
    subject(:checker) { described_class.new(changes_access) }

    before do
      allow(checker).to receive_messages(jira_enabled?: true, jira_integration: jira_integration)
      allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
    end

    context 'when no Jira checks are enabled' do
      before do
        allow(checker).to receive(:any_jira_check_enabled?).and_return(false)
      end

      it 'returns early without performing any checks' do
        expect(checker).not_to receive(:extract_jira_issue_keys)
        expect(checker).not_to receive(:find_jira_issue)
        expect(checker).not_to receive(:verify_issue_exists)
        expect(checker).not_to receive(:verify_assignee)
        expect(checker).not_to receive(:verify_status)

        expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
      end
    end

    context 'when Jira checks are enabled' do
      before do
        allow(checker).to receive(:any_jira_check_enabled?).and_return(true)
      end

      context 'when no Jira issue keys are found in commit message' do
        before do
          allow(checker).to receive(:extract_jira_issue_keys).with('Fix issue ABC-123').and_return([])
        end

        it 'raises ForbiddenError without calling find_jira_issue' do
          expect(checker).not_to receive(:find_jira_issue)
          expect(checker).not_to receive(:verify_issue_exists)
          expect(checker).not_to receive(:verify_assignee)
          expect(checker).not_to receive(:verify_status)

          expect { checker.send(:jira_verification_check, commit) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'No Jira issue found in commit message'
          )
        end
      end

      context 'when Jira issue keys are found' do
        before do
          allow(checker).to receive(:extract_jira_issue_keys).with('Fix issue ABC-123').and_return(%w[ABC-123
            DEF-456])
        end

        it 'uses only the first issue key' do
          allow(checker).to receive_messages(
            find_jira_issue: jira_issue,
            jira_exists_check_enabled?: true,
            jira_assignee_check_enabled?: false,
            jira_status_check_enabled?: false
          )

          expect(checker).to receive(:find_jira_issue).with('ABC-123').and_return(jira_issue)
          expect(checker).not_to receive(:find_jira_issue).with('DEF-456')

          expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
        end

        context 'when jira_exists_check is enabled' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: true,
              jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: false
            )
          end

          context 'when issue exists' do
            before do
              allow(checker).to receive(:find_jira_issue).with('ABC-123').and_return(jira_issue)
              allow(jira_issue).to receive(:present?).and_return(true)
            end

            it 'calls verify_issue_exists and continues with other checks' do
              expect(checker).to receive(:verify_issue_exists).with('ABC-123', jira_issue)
              expect(checker).not_to receive(:verify_assignee)
              expect(checker).not_to receive(:verify_status)

              expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
            end
          end

          context 'when issue does not exist' do
            before do
              allow(checker).to receive(:find_jira_issue).with('ABC-123').and_return(nil)
            end

            it 'calls verify_issue_exists which raises error' do
              expect(checker).to receive(:verify_issue_exists).with('ABC-123', nil).and_call_original
              expect(checker).not_to receive(:verify_assignee)
              expect(checker).not_to receive(:verify_status)

              expect { checker.send(:jira_verification_check, commit) }.to raise_error(
                Gitlab::GitAccess::ForbiddenError,
                'Jira issue ABC-123 does not exist'
              )
            end
          end
        end

        context 'when jira_exists_check is disabled' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: false
            )
          end

          context 'when issue exists' do
            before do
              allow(checker).to receive(:find_jira_issue).with('ABC-123').and_return(jira_issue)
              allow(jira_issue).to receive(:present?).and_return(true)
            end

            it 'skips verify_issue_exists and continues with other checks' do
              expect(checker).not_to receive(:verify_issue_exists)
              expect(checker).not_to receive(:verify_assignee)
              expect(checker).not_to receive(:verify_status)

              expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
            end
          end

          context 'when issue does not exist' do
            before do
              allow(checker).to receive(:find_jira_issue).with('ABC-123').and_return(nil)
            end

            it 'returns early without calling other verification methods' do
              expect(checker).not_to receive(:verify_issue_exists)
              expect(checker).not_to receive(:verify_assignee)
              expect(checker).not_to receive(:verify_status)

              expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
            end
          end
        end

        context 'when jira_assignee_check is enabled' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true,
              jira_status_check_enabled?: false,
              find_jira_issue: jira_issue
            )
            allow(jira_issue).to receive(:present?).and_return(true)
          end

          it 'calls verify_assignee with issue and commit' do
            expect(checker).to receive(:verify_assignee).with(jira_issue, commit)
            expect(checker).not_to receive(:verify_status)

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end

        context 'when jira_status_check is enabled' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: true,
              find_jira_issue: jira_issue
            )
            allow(jira_issue).to receive(:present?).and_return(true)
          end

          it 'calls verify_status with issue' do
            expect(checker).to receive(:verify_status).with(jira_issue)

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end

        context 'when multiple checks are enabled' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: true,
              jira_assignee_check_enabled?: true,
              jira_status_check_enabled?: true,
              find_jira_issue: jira_issue
            )
            allow(jira_issue).to receive(:present?).and_return(true)
          end

          it 'calls all verification methods in correct order' do
            expect(checker).to receive(:verify_issue_exists).with('ABC-123', jira_issue).ordered
            expect(checker).to receive(:verify_assignee).with(jira_issue, commit).ordered
            expect(checker).to receive(:verify_status).with(jira_issue).ordered

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end

        context 'when assignee and status checks are enabled but exists check is disabled and issue is nil' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true,
              jira_status_check_enabled?: true,
              find_jira_issue: nil
            )
          end

          it 'returns early without calling assignee or status verification' do
            expect(checker).not_to receive(:verify_issue_exists)
            expect(checker).not_to receive(:verify_assignee)
            expect(checker).not_to receive(:verify_status)

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end

        context 'when only assignee check is enabled and issue exists' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: true,
              jira_status_check_enabled?: false,
              find_jira_issue: jira_issue
            )
            allow(jira_issue).to receive(:present?).and_return(true)
          end

          it 'calls only verify_assignee' do
            expect(checker).not_to receive(:verify_issue_exists)
            expect(checker).to receive(:verify_assignee).with(jira_issue, commit)
            expect(checker).not_to receive(:verify_status)

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end

        context 'when only status check is enabled and issue exists' do
          before do
            allow(checker).to receive_messages(
              jira_exists_check_enabled?: false,
              jira_assignee_check_enabled?: false,
              jira_status_check_enabled?: true,
              find_jira_issue: jira_issue
            )
            allow(jira_issue).to receive(:present?).and_return(true)
          end

          it 'calls only verify_status' do
            expect(checker).not_to receive(:verify_issue_exists)
            expect(checker).not_to receive(:verify_assignee)
            expect(checker).to receive(:verify_status).with(jira_issue)

            expect { checker.send(:jira_verification_check, commit) }.not_to raise_error
          end
        end
      end
    end
  end

  describe '#jira_check_enabled?' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when jira_integration is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration exists but data_fields is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration and data_fields exist' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when jira_check_enabled is true' do
        before do
          allow(jira_data_fields).to receive(:jira_check_enabled).and_return(true)
        end

        it 'returns true' do
          expect(checker.send(:jira_check_enabled?)).to be true
        end
      end

      context 'when jira_check_enabled is false' do
        before do
          allow(jira_data_fields).to receive(:jira_check_enabled).and_return(false)
        end

        it 'returns false' do
          expect(checker.send(:jira_check_enabled?)).to be false
        end
      end

      context 'when jira_check_enabled is nil' do
        before do
          allow(jira_data_fields).to receive(:jira_check_enabled).and_return(nil)
        end

        it 'returns nil' do
          expect(checker.send(:jira_check_enabled?)).to be_nil
        end
      end
    end

    context 'when testing the full method chain' do
      it 'calls the correct method chain' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        expect(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        expect(jira_data_fields).to receive(:jira_check_enabled).and_return(true)

        result = checker.send(:jira_check_enabled?)
        expect(result).to be true
      end

      it 'handles safe navigation properly when integration exists but data_fields method returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)

        expect { checker.send(:jira_check_enabled?) }.not_to raise_error
        expect(checker.send(:jira_check_enabled?)).to be_nil
      end
    end
  end

  describe '#jira_exists_check_enabled?' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when jira_integration is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_exists_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration exists but data_fields is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_exists_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration and data_fields exist' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when jira_exists_check_enabled is true' do
        before do
          allow(jira_data_fields).to receive(:jira_exists_check_enabled).and_return(true)
        end

        it 'returns true' do
          expect(checker.send(:jira_exists_check_enabled?)).to be true
        end
      end

      context 'when jira_exists_check_enabled is false' do
        before do
          allow(jira_data_fields).to receive(:jira_exists_check_enabled).and_return(false)
        end

        it 'returns false' do
          expect(checker.send(:jira_exists_check_enabled?)).to be false
        end
      end

      context 'when jira_exists_check_enabled is nil' do
        before do
          allow(jira_data_fields).to receive(:jira_exists_check_enabled).and_return(nil)
        end

        it 'returns nil' do
          expect(checker.send(:jira_exists_check_enabled?)).to be_nil
        end
      end
    end

    context 'when testing the full method chain' do
      it 'calls the correct method chain' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        expect(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        expect(jira_data_fields).to receive(:jira_exists_check_enabled).and_return(true)

        result = checker.send(:jira_exists_check_enabled?)
        expect(result).to be true
      end

      it 'handles safe navigation properly when integration exists but data_fields method returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)

        expect { checker.send(:jira_exists_check_enabled?) }.not_to raise_error
        expect(checker.send(:jira_exists_check_enabled?)).to be_nil
      end
    end
  end

  describe '#jira_assignee_check_enabled?' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when jira_integration is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_assignee_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration exists but data_fields is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_assignee_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration and data_fields exist' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when jira_assignee_check_enabled is true' do
        before do
          allow(jira_data_fields).to receive(:jira_assignee_check_enabled).and_return(true)
        end

        it 'returns true' do
          expect(checker.send(:jira_assignee_check_enabled?)).to be true
        end
      end

      context 'when jira_assignee_check_enabled is false' do
        before do
          allow(jira_data_fields).to receive(:jira_assignee_check_enabled).and_return(false)
        end

        it 'returns false' do
          expect(checker.send(:jira_assignee_check_enabled?)).to be false
        end
      end

      context 'when jira_assignee_check_enabled is nil' do
        before do
          allow(jira_data_fields).to receive(:jira_assignee_check_enabled).and_return(nil)
        end

        it 'returns nil' do
          expect(checker.send(:jira_assignee_check_enabled?)).to be_nil
        end
      end
    end

    context 'when testing the full method chain' do
      it 'calls the correct method chain' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        expect(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        expect(jira_data_fields).to receive(:jira_assignee_check_enabled).and_return(true)

        result = checker.send(:jira_assignee_check_enabled?)
        expect(result).to be true
      end

      it 'handles safe navigation properly when integration exists but data_fields method returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)

        expect { checker.send(:jira_assignee_check_enabled?) }.not_to raise_error
        expect(checker.send(:jira_assignee_check_enabled?)).to be_nil
      end
    end
  end

  describe '#jira_status_check_enabled?' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when jira_integration is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_status_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration exists but data_fields is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)
      end

      it 'returns nil due to safe navigation' do
        expect(checker.send(:jira_status_check_enabled?)).to be_nil
      end
    end

    context 'when jira_integration and data_fields exist' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when jira_status_check_enabled is true' do
        before do
          allow(jira_data_fields).to receive(:jira_status_check_enabled).and_return(true)
        end

        it 'returns true' do
          expect(checker.send(:jira_status_check_enabled?)).to be true
        end
      end

      context 'when jira_status_check_enabled is false' do
        before do
          allow(jira_data_fields).to receive(:jira_status_check_enabled).and_return(false)
        end

        it 'returns false' do
          expect(checker.send(:jira_status_check_enabled?)).to be false
        end
      end

      context 'when jira_status_check_enabled is nil' do
        before do
          allow(jira_data_fields).to receive(:jira_status_check_enabled).and_return(nil)
        end

        it 'returns nil' do
          expect(checker.send(:jira_status_check_enabled?)).to be_nil
        end
      end
    end

    context 'when testing the full method chain' do
      it 'calls the correct method chain' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        expect(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        expect(jira_data_fields).to receive(:jira_status_check_enabled).and_return(true)

        result = checker.send(:jira_status_check_enabled?)
        expect(result).to be true
      end

      it 'handles safe navigation properly when integration exists but data_fields method returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)

        expect { checker.send(:jira_status_check_enabled?) }.not_to raise_error
        expect(checker.send(:jira_status_check_enabled?)).to be_nil
      end
    end
  end

  describe '#jira_allowed_statuses' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when jira_integration is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(nil)
      end

      it 'returns empty array due to safe navigation and fallback' do
        expect(checker.send(:jira_allowed_statuses)).to eq([])
      end
    end

    context 'when jira_integration exists but data_fields is nil' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)
      end

      it 'returns empty array due to safe navigation and fallback' do
        expect(checker.send(:jira_allowed_statuses)).to eq([])
      end
    end

    context 'when jira_integration and data_fields exist' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
      end

      context 'when jira_allowed_statuses returns an array' do
        before do
          allow(jira_data_fields).to receive(:jira_allowed_statuses).and_return(['In Progress', 'Done', 'To Do'])
        end

        it 'returns the array' do
          expect(checker.send(:jira_allowed_statuses)).to eq(['In Progress', 'Done', 'To Do'])
        end
      end

      context 'when jira_allowed_statuses returns an empty array' do
        before do
          allow(jira_data_fields).to receive(:jira_allowed_statuses).and_return([])
        end

        it 'returns the empty array' do
          expect(checker.send(:jira_allowed_statuses)).to eq([])
        end
      end

      context 'when jira_allowed_statuses returns nil' do
        before do
          allow(jira_data_fields).to receive(:jira_allowed_statuses).and_return(nil)
        end

        it 'returns empty array due to fallback' do
          expect(checker.send(:jira_allowed_statuses)).to eq([])
        end
      end

      context 'when jira_allowed_statuses returns a single status' do
        before do
          allow(jira_data_fields).to receive(:jira_allowed_statuses).and_return(['Done'])
        end

        it 'returns the single-element array' do
          expect(checker.send(:jira_allowed_statuses)).to eq(['Done'])
        end
      end
    end

    context 'when testing the full method chain' do
      it 'calls the correct method chain' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        expect(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        expect(jira_data_fields).to receive(:jira_allowed_statuses).and_return(['In Progress', 'Done'])

        result = checker.send(:jira_allowed_statuses)
        expect(result).to eq(['In Progress', 'Done'])
      end

      it 'handles safe navigation properly when integration exists but data_fields method returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(nil)

        expect { checker.send(:jira_allowed_statuses) }.not_to raise_error
        expect(checker.send(:jira_allowed_statuses)).to eq([])
      end

      it 'handles the fallback when data_fields exists but jira_allowed_statuses returns nil' do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:data_fields).and_return(jira_data_fields)
        allow(jira_data_fields).to receive(:jira_allowed_statuses).and_return(nil)

        expect { checker.send(:jira_allowed_statuses) }.not_to raise_error
        expect(checker.send(:jira_allowed_statuses)).to eq([])
      end
    end
  end

  describe '#any_jira_check_enabled?' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    context 'when all checks are disabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: false,
          jira_assignee_check_enabled?: false,
          jira_status_check_enabled?: false
        )
      end

      it 'returns false' do
        expect(checker.send(:any_jira_check_enabled?)).to be false
      end
    end

    context 'when only exists check is enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: true,
          jira_assignee_check_enabled?: false,
          jira_status_check_enabled?: false
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when only assignee check is enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: false,
          jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: false
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when only status check is enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: false,
          jira_assignee_check_enabled?: false,
          jira_status_check_enabled?: true
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when exists and assignee checks are enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: true,
          jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: false
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when exists and status checks are enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: true,
          jira_assignee_check_enabled?: false,
          jira_status_check_enabled?: true
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when assignee and status checks are enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: false,
          jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: true
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when all checks are enabled' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: true,
          jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: true
        )
      end

      it 'returns true' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when checks return nil values' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: nil,
          jira_assignee_check_enabled?: nil,
          jira_status_check_enabled?: nil
        )
      end

      it 'returns nil due to logical OR with all nil values' do
        expect(checker.send(:any_jira_check_enabled?)).to be_nil
      end
    end

    context 'when some checks return nil and others return false' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: nil,
          jira_assignee_check_enabled?: false,
          jira_status_check_enabled?: nil
        )
      end

      it 'returns nil due to logical OR evaluation with nil values' do
        expect(checker.send(:any_jira_check_enabled?)).to be_nil
      end
    end

    context 'when some checks return nil and one returns true' do
      before do
        allow(checker).to receive_messages(
          jira_exists_check_enabled?: nil,
          jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: nil
        )
      end

      it 'returns true due to short-circuit evaluation' do
        expect(checker.send(:any_jira_check_enabled?)).to be true
      end
    end

    context 'when testing method call order and short-circuit evaluation' do
      it 'calls methods in order and short-circuits on first truthy value' do
        allow(checker).to receive_messages(jira_exists_check_enabled?: true, jira_assignee_check_enabled?: true,
          jira_status_check_enabled?: true)

        expect(checker).to receive(:jira_exists_check_enabled?).and_return(true)
        # Due to short-circuit evaluation, these should not be called when first returns true
        expect(checker).not_to receive(:jira_assignee_check_enabled?)
        expect(checker).not_to receive(:jira_status_check_enabled?)

        result = checker.send(:any_jira_check_enabled?)
        expect(result).to be true
      end

      it 'calls all methods when all return false' do
        expect(checker).to receive(:jira_exists_check_enabled?).and_return(false).ordered
        expect(checker).to receive(:jira_assignee_check_enabled?).and_return(false).ordered
        expect(checker).to receive(:jira_status_check_enabled?).and_return(false).ordered

        result = checker.send(:any_jira_check_enabled?)
        expect(result).to be false
      end

      it 'short-circuits on second method when it returns true' do
        expect(checker).to receive(:jira_exists_check_enabled?).and_return(false).ordered
        expect(checker).to receive(:jira_assignee_check_enabled?).and_return(true).ordered
        expect(checker).not_to receive(:jira_status_check_enabled?)

        result = checker.send(:any_jira_check_enabled?)
        expect(result).to be true
      end
    end
  end

  describe '#find_jira_integration' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }
    let(:project_integration) { instance_double(Integrations::Jira) }
    let(:group_integration) { instance_double(Integrations::Jira) }
    let(:parent_group_integration) { instance_double(Integrations::Jira) }
    let(:root_group_integration) { instance_double(Integrations::Jira) }
    let(:instance_integration) { instance_double(Integrations::Jira) }

    subject(:checker) { described_class.new(mock_changes_access) }

    before do
      allow(::Integrations::Jira).to receive(:instance_level).and_return(instance_integration)
    end

    context 'when project has direct integration' do
      before do
        allow(project).to receive(:jira_integration).and_return(project_integration)
        allow(project_integration).to receive(:activated?).and_return(true)
      end

      it 'returns project integration without checking groups' do
        expect(project).not_to receive(:group)
        result = checker.send(:find_jira_integration)
        expect(result).to eq(project_integration)
      end
    end

    context 'when project has no integration but group hierarchy exists' do
      let(:root_group) { instance_double(Group) }
      let(:parent_group) { instance_double(Group) }
      let(:child_group) { instance_double(Group) }

      before do
        allow(project).to receive_messages(jira_integration: nil, group: child_group)
      end

      context 'with single-level group hierarchy' do
        before do
          allow(child_group).to receive_messages(self_and_ancestors: [child_group], jira_integration: group_integration)
        end

        context 'when group integration is activated' do
          before do
            allow(group_integration).to receive(:activated?).and_return(true)
          end

          it 'returns group integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(group_integration)
          end
        end

        context 'when group integration is not activated' do
          before do
            allow(group_integration).to receive(:activated?).and_return(false)
          end

          it 'falls back to instance integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(instance_integration)
          end
        end
      end

      context 'with multi-level group hierarchy' do
        before do
          allow(child_group).to receive(:self_and_ancestors).and_return([child_group, parent_group, root_group])
        end

        context 'when child group has activated integration' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(group_integration)
            allow(group_integration).to receive(:activated?).and_return(true)
          end

          it 'returns child group integration without checking ancestors' do
            expect(parent_group).not_to receive(:jira_integration)
            expect(root_group).not_to receive(:jira_integration)
            result = checker.send(:find_jira_integration)
            expect(result).to eq(group_integration)
          end
        end

        context 'when child group has no integration but parent does' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(nil)
            allow(parent_group).to receive(:jira_integration).and_return(parent_group_integration)
            allow(parent_group_integration).to receive(:activated?).and_return(true)
          end

          it 'returns parent group integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(parent_group_integration)
          end
        end

        context 'when child and parent have no integration but root does' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(nil)
            allow(parent_group).to receive(:jira_integration).and_return(nil)
            allow(root_group).to receive(:jira_integration).and_return(root_group_integration)
            allow(root_group_integration).to receive(:activated?).and_return(true)
          end

          it 'returns root group integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(root_group_integration)
          end
        end

        context 'when child has deactivated integration but parent has activated one' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(group_integration)
            allow(group_integration).to receive(:activated?).and_return(false)
            allow(parent_group).to receive(:jira_integration).and_return(parent_group_integration)
            allow(parent_group_integration).to receive(:activated?).and_return(true)
          end

          it 'skips deactivated child integration and returns parent integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(parent_group_integration)
          end
        end

        context 'when no group in hierarchy has activated integration' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(group_integration)
            allow(group_integration).to receive(:activated?).and_return(false)
            allow(parent_group).to receive(:jira_integration).and_return(parent_group_integration)
            allow(parent_group_integration).to receive(:activated?).and_return(false)
            allow(root_group).to receive(:jira_integration).and_return(root_group_integration)
            allow(root_group_integration).to receive(:activated?).and_return(false)
          end

          it 'falls back to instance integration' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(instance_integration)
          end
        end

        context 'when some groups have nil integrations' do
          before do
            allow(child_group).to receive(:jira_integration).and_return(nil)
            allow(parent_group).to receive(:jira_integration).and_return(nil)
            allow(root_group).to receive(:jira_integration).and_return(root_group_integration)
            allow(root_group_integration).to receive(:activated?).and_return(true)
          end

          it 'skips nil integrations and finds the first activated one' do
            result = checker.send(:find_jira_integration)
            expect(result).to eq(root_group_integration)
          end
        end
      end
    end

    context 'when project has no group' do
      before do
        allow(project).to receive_messages(jira_integration: nil, group: nil)
      end

      it 'falls back to instance integration' do
        result = checker.send(:find_jira_integration)
        expect(result).to eq(instance_integration)
      end
    end

    context 'when project has deactivated integration and group has activated one' do
      let(:child_group) { instance_double(Group) }

      before do
        allow(project_integration).to receive(:activated?).and_return(false)
        allow(project).to receive_messages(jira_integration: project_integration, group: child_group)
        allow(child_group).to receive_messages(self_and_ancestors: [child_group], jira_integration: group_integration)
        allow(group_integration).to receive(:activated?).and_return(true)
      end

      it 'skips deactivated project integration and returns group integration' do
        result = checker.send(:find_jira_integration)
        expect(result).to eq(group_integration)
      end
    end

    context 'when integration priority verification' do
      let(:root_group) { instance_double(Group) }
      let(:parent_group) { instance_double(Group) }
      let(:child_group) { instance_double(Group) }

      before do
        allow(project).to receive(:group).and_return(child_group)
        allow(child_group).to receive(:self_and_ancestors).and_return([child_group, parent_group, root_group])
      end

      context 'when project, child, and parent all have activated integrations' do
        before do
          allow(project).to receive(:jira_integration).and_return(project_integration)
          allow(project_integration).to receive(:activated?).and_return(true)
          allow(child_group).to receive(:jira_integration).and_return(group_integration)
          allow(group_integration).to receive(:activated?).and_return(true)
          allow(parent_group).to receive(:jira_integration).and_return(parent_group_integration)
          allow(parent_group_integration).to receive(:activated?).and_return(true)
        end

        it 'returns project integration (highest priority)' do
          expect(child_group).not_to receive(:jira_integration)
          expect(parent_group).not_to receive(:jira_integration)
          result = checker.send(:find_jira_integration)
          expect(result).to eq(project_integration)
        end
      end

      context 'when child and parent groups both have activated integrations' do
        before do
          allow(project).to receive(:jira_integration).and_return(nil)
          allow(child_group).to receive(:jira_integration).and_return(group_integration)
          allow(group_integration).to receive(:activated?).and_return(true)
          allow(parent_group).to receive(:jira_integration).and_return(parent_group_integration)
          allow(parent_group_integration).to receive(:activated?).and_return(true)
        end

        it 'returns child group integration (closer in hierarchy)' do
          expect(parent_group).not_to receive(:jira_integration)
          result = checker.send(:find_jira_integration)
          expect(result).to eq(group_integration)
        end
      end
    end
  end

  describe 'private methods' do
    let(:mock_changes_access) { instance_double(Gitlab::Checks::ChangesAccess, project: project) }

    subject(:checker) { described_class.new(mock_changes_access) }

    describe '#extract_jira_issue_keys' do
      let(:pattern) { /[A-Z]+-\d+/ }

      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
        allow(jira_integration).to receive(:reference_pattern).and_return(pattern)
      end

      it 'extracts Jira issue keys from commit message' do
        message = 'Fix issues ABC-123 and DEF-456'
        result = checker.send(:extract_jira_issue_keys, message)
        expect(result).to contain_exactly('ABC-123', 'DEF-456')
      end

      it 'returns empty array when no pattern is configured' do
        allow(jira_integration).to receive(:reference_pattern).and_return(nil)
        result = checker.send(:extract_jira_issue_keys, 'Fix issue ABC-123')
        expect(result).to eq([])
      end

      it 'returns unique issue keys' do
        message = 'Fix ABC-123 and also ABC-123'
        result = checker.send(:extract_jira_issue_keys, message)
        expect(result).to eq(['ABC-123'])
      end

      context 'when using UntrustedRegexp pattern' do
        let(:untrusted_pattern) { Gitlab::UntrustedRegexp.new('\\b(?P<issue>[A-Z]+-\\d+)') }

        before do
          allow(jira_integration).to receive(:reference_pattern).and_return(untrusted_pattern)
        end

        it 'works correctly with UntrustedRegexp pattern' do
          message = 'Fix issues ABC-123 and DEF-456'
          result = checker.send(:extract_jira_issue_keys, message)
          expect(result).to contain_exactly('ABC-123', 'DEF-456')
        end

        it 'handles single issue key with UntrustedRegexp' do
          message = 'Fix issue XYZ-999'
          result = checker.send(:extract_jira_issue_keys, message)
          expect(result).to eq(['XYZ-999'])
        end

        it 'returns empty array when no matches found with UntrustedRegexp' do
          message = 'No Jira issues here'
          result = checker.send(:extract_jira_issue_keys, message)
          expect(result).to eq([])
        end

        it 'returns unique issue keys with UntrustedRegexp' do
          message = 'Fix ABC-123 and also ABC-123 again'
          result = checker.send(:extract_jira_issue_keys, message)
          expect(result).to eq(['ABC-123'])
        end
      end
    end

    describe '#find_jira_issue' do
      before do
        allow(checker).to receive(:jira_integration).and_return(jira_integration)
      end

      it 'delegates to jira_integration.find_issue' do
        expect(jira_integration).to receive(:find_issue).with('ABC-123').and_return(jira_issue)
        result = checker.send(:find_jira_issue, 'ABC-123')
        expect(result).to eq(jira_issue)
      end

      it 'handles and re-raises errors with proper context' do
        error = StandardError.new('API Error')
        allow(jira_integration).to receive(:find_issue).and_raise(error)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        expect { checker.send(:find_jira_issue, 'ABC-123') }.to raise_error(
          Gitlab::GitAccess::ForbiddenError,
          'Failed to connect to Jira to verify issue ABC-123. Error: API Error'
        )

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error, issue_key: 'ABC-123')
      end
    end

    describe '#verify_issue_exists' do
      context 'when issue is present' do
        before do
          allow(jira_issue).to receive(:present?).and_return(true)
        end

        it 'returns without raising an error' do
          expect { checker.send(:verify_issue_exists, 'ABC-123', jira_issue) }.not_to raise_error
        end

        it 'returns nil' do
          result = checker.send(:verify_issue_exists, 'ABC-123', jira_issue)
          expect(result).to be_nil
        end
      end

      context 'when issue is nil' do
        it 'raises ForbiddenError with correct message' do
          expect { checker.send(:verify_issue_exists, 'ABC-123', nil) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'Jira issue ABC-123 does not exist'
          )
        end
      end

      context 'when issue is present but returns false for present?' do
        # rubocop:disable RSpec/VerifiedDoubles -- JIRA gem classes are external
        let(:falsy_issue) { double('falsy_issue') }
        # rubocop:enable RSpec/VerifiedDoubles

        before do
          allow(falsy_issue).to receive(:present?).and_return(false)
        end

        it 'raises ForbiddenError with correct message' do
          expect { checker.send(:verify_issue_exists, 'DEF-456', falsy_issue) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'Jira issue DEF-456 does not exist'
          )
        end
      end

      context 'with different issue keys' do
        it 'includes the correct issue key in error message for different keys' do
          expect { checker.send(:verify_issue_exists, 'XYZ-999', nil) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'Jira issue XYZ-999 does not exist'
          )
        end
      end
    end
  end
end
