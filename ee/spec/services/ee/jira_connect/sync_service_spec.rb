# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JiraConnect::SyncService, feature_category: :team_planning do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:jira_connect_subscription) { create(:jira_connect_subscription, namespace: project.namespace) }

    subject(:service) { described_class.new(project) }

    it 'calls the Jira Connect API' do
      expect_next_instance_of(Atlassian::JiraConnect::Client) do |client|
        expect(client).to receive(:send_info).and_return([])
      end

      service.execute
    end

    it 'does not call the Jira Connect API when the GitLab for Jira Cloud integration is blocked by settings' do
      allow(Integrations::JiraCloudApp).to receive(:blocked_by_settings?).and_return(true)

      expect(Atlassian::JiraConnect::Client).not_to receive(:new)

      service.execute
    end
  end
end
