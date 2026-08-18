# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ExternalIssueLinkEntity, feature_category: :vulnerability_management do
  let_it_be(:project) { build(:project, :repository) }
  let_it_be(:jira_integration) { build(:jira_integration, project: project) }
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:vulnerability) { build(:vulnerability, project: project) }

  let(:opts) { {} }

  let(:external_issue_link) { build(:vulnerabilities_external_issue_link, vulnerability: vulnerability, author: user) }

  let(:entity) do
    described_class.represent(external_issue_link, opts)
  end

  describe '#as_json' do
    let(:reporter) do
      {
        'displayName' => 'reporter',
        'avatarUrls' => { '48x48' => 'http://reporter.avatar' },
        'name' => 'reporter@reporter.com'
      }
    end

    let(:assignee) do
      {
        'displayName' => 'assignee',
        'avatarUrls' => { '48x48' => 'http://assignee.avatar' },
        'name' => 'assignee@assignee.com'
      }
    end

    # rubocop:disable RSpec/VerifiedDoubles -- those are not models or objects
    let(:jira_issue_attributes) do
      {
        summary: 'Title with <h1>HTML</h1>',
        created: '2020-06-25T15:39:30.000+0000',
        updated: '2020-06-26T15:38:32.000+0000',
        resolutiondate: '2020-06-27T13:23:51.000+0000',
        labels: ['backend'],
        fields: {
          'reporter' => reporter,
          'assignee' => assignee
        },
        project: double(key: 'GL'),
        key: 'GL-5',
        status: double(name: 'To Do')
      }
    end

    let(:jira_issue) { double(jira_issue_attributes) }
    # rubocop:enable RSpec/VerifiedDoubles

    before do
      allow(project).to receive(:jira_integration).and_return(jira_integration)
      allow(jira_integration).to receive(:find_issue)
        .with(external_issue_link.external_issue_key)
        .and_return(jira_issue)
    end

    subject(:serialized_external_issue_link) { entity.as_json }

    shared_examples 'required fields' do
      it 'are present' do
        expect(serialized_external_issue_link).to include(:external_issue_details, :created_at, :updated_at, :author)
      end
    end

    context 'when the request is not nil' do
      let(:opts) { { request: request } }

      context 'when the user is available' do
        let(:request) { EntityRequest.new(current_user: user) }

        it_behaves_like 'required fields'

        context 'when the user can not read issue' do
          it 'does not contain issue_url' do
            expect(serialized_external_issue_link).not_to include(:issue_url)
          end
        end

        context 'when the user can read issue' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :read_issue, project).and_return(true)
          end

          it 'contains URL to the issue' do
            tracker_url = serialized_external_issue_link.dig(*%i[external_issue_details web_url])
            expect(tracker_url).not_to be_empty
          end
        end
      end

      context 'when the user is not available' do
        let(:request) { EntityRequest.new({}) }

        it_behaves_like 'required fields'

        it 'does not show issue details' do
          expect(serialized_external_issue_link[:external_issue_details]).to be_empty
        end
      end
    end

    context 'when the request is nil' do
      it_behaves_like 'required fields'

      it 'does not show issue details' do
        expect(serialized_external_issue_link[:external_issue_details]).to be_empty
      end
    end
  end
end
