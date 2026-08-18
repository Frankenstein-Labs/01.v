# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::JiraIntegration::VerifyCommitService, feature_category: :team_planning do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }
  let(:integration) { create(:jira_integration, project: project) }
  let(:jira_issue) do
    double('JIRA::Resource::Issue', # rubocop:disable RSpec/VerifiedDoubles -- disable Rubocop because double is necessary to pass the tests
      key: 'TEST-123',
      status: double('JIRA::Resource::Status', name: 'In Progress')) # rubocop:disable RSpec/VerifiedDoubles -- disable Rubocop because double is necessary to pass the tests
  end

  let(:jira_assignee) { double('JIRA::Resource::User', emailAddress: user.email, displayName: user.name) } # rubocop:disable RSpec/VerifiedDoubles -- disable Rubocop because double is necessary to pass the tests

  before do
    # Allow the service to find the integration
    allow(service).to receive(:jira_integration).and_return(integration)
    allow(integration).to receive_messages(find_issue: jira_issue, reference_pattern: /TEST-\d+/, activated?: true)

    # Set up jira_issue to have an assignee
    allow(jira_issue).to receive(:assignee).and_return(jira_assignee)
  end

  describe '#extract_issue_keys' do
    it 'returns empty array for nil message' do
      expect(service.extract_issue_keys(nil)).to eq([])
    end

    it 'returns empty array if integration is not activated' do
      allow(integration).to receive(:activated?).and_return(false)

      expect(service.extract_issue_keys('TEST-123')).to eq([])
    end

    it 'returns empty array if pattern is nil' do
      allow(integration).to receive(:reference_pattern).and_return(nil)

      expect(service.extract_issue_keys('TEST-123')).to eq([])
    end

    it 'returns issue keys that match the pattern' do
      expect(service.extract_issue_keys('Fix issue TEST-123')).to eq(['TEST-123'])
    end

    it 'returns unique issue keys' do
      expect(service.extract_issue_keys('Fix issues TEST-123 and TEST-123')).to eq(['TEST-123'])
    end

    it 'returns multiple unique issue keys' do
      expect(service.extract_issue_keys('Fix issues TEST-123 and TEST-456')).to eq(%w[TEST-123 TEST-456])
    end
  end

  describe '#verify_issue_exists' do
    it 'returns false if integration is not activated' do
      allow(integration).to receive(:activated?).and_return(false)

      expect(service.verify_issue_exists('TEST-123')).to be_falsey
    end

    it 'returns true if issue exists' do
      expect(service.verify_issue_exists('TEST-123')).to be_truthy
    end

    it 'returns false if issue does not exist' do
      allow(integration).to receive(:find_issue).and_return(nil)

      expect(service.verify_issue_exists('TEST-123')).to be_falsey
    end

    it 'returns false and tracks exception if Jira API raises error' do
      allow(integration).to receive(:find_issue).and_raise(StandardError.new('API error'))
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(service.verify_issue_exists('TEST-123')).to be_falsey
    end
  end

  describe '#verify_user_is_assignee' do
    it 'returns false if integration is not activated' do
      allow(integration).to receive(:activated?).and_return(false)

      expect(service.verify_user_is_assignee('TEST-123', user.email, user.name)).to be_falsey
    end

    it 'returns false if issue does not exist' do
      allow(integration).to receive(:find_issue).and_return(nil)

      expect(service.verify_user_is_assignee('TEST-123', user.email, user.name)).to be_falsey
    end

    it 'returns false if issue has no assignee' do
      allow(jira_issue).to receive(:assignee).and_return(nil)

      expect(service.verify_user_is_assignee('TEST-123', user.email, user.name)).to be_falsey
    end

    it 'returns true if user email matches assignee email' do
      expect(service.verify_user_is_assignee('TEST-123', user.email, 'Different Name')).to be_truthy
    end

    it 'returns true if user name matches assignee name' do
      allow(jira_assignee).to receive(:emailAddress).and_return('different@example.com')

      expect(service.verify_user_is_assignee('TEST-123', 'different2@example.com', user.name)).to be_truthy
    end

    it 'returns false if neither email nor name match' do
      allow(jira_assignee).to receive_messages(emailAddress: 'different@example.com', displayName: 'Different Name')

      expect(service.verify_user_is_assignee('TEST-123', 'user@example.com', 'User Name')).to be_falsey
    end

    it 'returns false and tracks exception if Jira API raises error' do
      allow(integration).to receive(:find_issue).and_raise(StandardError.new('API error'))
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(service.verify_user_is_assignee('TEST-123', user.email, user.name)).to be_falsey
    end
  end

  describe '#verify_issue_status' do
    it 'returns false if allowed_statuses is blank' do
      expect(service.verify_issue_status('TEST-123', [])).to be_falsey
    end

    it 'returns false if integration is not activated' do
      allow(integration).to receive(:activated?).and_return(false)

      expect(service.verify_issue_status('TEST-123', ['In Progress'])).to be_falsey
    end

    it 'returns false if issue does not exist' do
      allow(integration).to receive(:find_issue).and_return(nil)

      expect(service.verify_issue_status('TEST-123', ['In Progress'])).to be_falsey
    end

    it 'returns false if issue has no status' do
      allow(jira_issue).to receive(:status).and_return(nil)

      expect(service.verify_issue_status('TEST-123', ['In Progress'])).to be_falsey
    end

    it 'returns true if issue status is in allowed statuses' do
      expect(service.verify_issue_status('TEST-123', ['Open', 'In Progress'])).to be_truthy
    end

    it 'returns false if issue status is not in allowed statuses' do
      expect(service.verify_issue_status('TEST-123', %w[Open Ready])).to be_falsey
    end

    it 'returns false and tracks exception if Jira API raises error' do
      allow(integration).to receive(:find_issue).and_raise(StandardError.new('API error'))
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(service.verify_issue_status('TEST-123', ['In Progress'])).to be_falsey
    end
  end

  describe '#issue_status' do
    it 'returns nil if integration is not activated' do
      allow(integration).to receive(:activated?).and_return(false)

      expect(service.issue_status('TEST-123')).to be_nil
    end

    it 'returns nil if issue does not exist' do
      allow(integration).to receive(:find_issue).and_return(nil)

      expect(service.issue_status('TEST-123')).to be_nil
    end

    it 'returns nil if issue has no status' do
      allow(jira_issue).to receive(:status).and_return(nil)

      expect(service.issue_status('TEST-123')).to be_nil
    end

    it 'returns the status name if issue has a status' do
      expect(service.issue_status('TEST-123')).to eq('In Progress')
    end

    it 'returns nil and tracks exception if Jira API raises error' do
      allow(integration).to receive(:find_issue).and_raise(StandardError.new('API error'))
      expect(Gitlab::ErrorTracking).to receive(:track_exception)

      expect(service.issue_status('TEST-123')).to be_nil
    end
  end

  describe '#jira_integration' do
    # Create a fresh service instance without the existing stubs
    let(:fresh_service) { described_class.new(project, user) }

    it 'memoizes the result of find_jira_integration' do
      allow(fresh_service).to receive(:find_jira_integration).and_return(integration)

      # Call the method twice
      result1 = fresh_service.send(:jira_integration)
      result2 = fresh_service.send(:jira_integration)

      # Verify find_jira_integration was called only once due to memoization
      expect(fresh_service).to have_received(:find_jira_integration).once
      expect(result1).to eq(integration)
      expect(result2).to eq(integration)
      expect(result1).to equal(result2) # Same object reference
    end

    it 'returns the same result as find_jira_integration' do
      allow(fresh_service).to receive(:find_jira_integration).and_return(integration)

      expect(fresh_service.send(:jira_integration)).to eq(integration)
    end

    it 'returns nil when find_jira_integration returns nil' do
      allow(fresh_service).to receive(:find_jira_integration).and_return(nil)

      expect(fresh_service.send(:jira_integration)).to be_nil
    end

    it 'delegates to find_jira_integration on first call' do
      expect(fresh_service).to receive(:find_jira_integration).and_return(integration)

      fresh_service.send(:jira_integration)
    end
  end

  describe '#find_jira_integration' do
    it 'returns project-level integration if it exists and is activated' do
      allow(project).to receive(:jira_integration).and_return(integration)
      allow(integration).to receive(:activated?).and_return(true)

      expect(service.send(:find_jira_integration)).to eq(integration)
    end

    it 'returns group-level integration if project-level does not exist' do
      group = create(:group)
      project.update!(group: group)

      allow(project).to receive(:jira_integration).and_return(nil)
      allow(project.group).to receive(:jira_integration).and_return(integration)
      allow(integration).to receive(:activated?).and_return(true)

      expect(service.send(:find_jira_integration)).to eq(integration)
    end

    it 'returns nil if no activated integration is found' do
      allow(project).to receive_messages(jira_integration: nil, group: nil)
      allow(Integrations::Jira).to receive(:instance_type).and_return([])

      expect(service.send(:find_jira_integration)).to be_nil
    end
  end
end
