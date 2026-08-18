# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::Base::ChatNotification, feature_category: :team_planning do
  let(:integration_class) do
    Class.new(Integration) do
      include Integrations::Base::ChatNotification
    end
  end

  subject(:integration) { integration_class.new }

  before do
    stub_const('TestIntegration', integration_class)
  end

  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project) }
    let_it_be(:label) { create(:group_label, group: group, name: 'Backend') }
    let_it_be(:issue) { create(:issue, project: project, labels: [label]) }
    let_it_be(:epic) { create(:work_item, :epic, namespace: group, labels: [label]) }

    let(:user) { build_stubbed(:user) }

    before do
      allow(integration).to receive(:webhook).and_return('https://example.gitlab.com/')
      integration.active = true
    end

    shared_examples 'notifies the chat integration' do
      specify do
        expect(integration).to receive(:notify).with(any_args)

        integration.execute(data)
      end
    end

    shared_examples 'does not notify the chat integration' do
      specify do
        expect(integration).not_to receive(:notify).with(any_args)

        integration.execute(data)
      end
    end

    shared_examples 'uses IssueMessage' do
      it 'uses IssueMessage' do
        expect(Integrations::ChatMessage::IssueMessage).to receive(:new).and_return(double)
        expect(integration).to receive(:notify).and_return(true)

        integration.execute(data)
      end
    end

    shared_examples 'routes work item events to issue channels' do
      it 'routes work item events to issue channels' do
        allow(integration).to receive(:issue_channel).and_return('#issues')

        expect(integration)
          .to receive(:notify)
          .with(any_args, hash_including(channel: ['#issues']))
          .and_return(true)

        integration.execute(data)
      end
    end

    context 'when Work Item events' do
      context 'with epic work item' do
        let(:data) { epic.to_hook_data(user) }

        it_behaves_like 'notifies the chat integration'
        it_behaves_like 'uses IssueMessage'
        it_behaves_like 'routes work item events to issue channels'

        context 'with label filtering' do
          subject(:integration) { integration_class.new(labels_to_be_notified: '~Backend') }

          it_behaves_like 'notifies the chat integration'
          it_behaves_like 'uses IssueMessage'
          it_behaves_like 'routes work item events to issue channels'

          context 'when no matching labels' do
            subject(:integration) { integration_class.new(labels_to_be_notified: '~Random Label') }

            it_behaves_like 'does not notify the chat integration'
          end
        end
      end
    end
  end
end
