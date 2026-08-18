# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Jira::JqlBuilderService, feature_category: :team_planning do
  describe '#execute' do
    let(:expected_project_keys) { project_keys }

    subject { described_class.new(project_keys, params).execute }

    shared_examples 'builds jql' do
      context 'when no params' do
        let(:params) { {} }

        it 'builds jql with default ordering' do
          expect(subject).to eq("project in (#{expected_project_keys}) order by created DESC")
        end

        context 'with special characters in project key' do
          subject { described_class.new('PROJECT\\KEY"', params).execute }

          it 'escapes quotes and backslashes' do
            expect(subject).to eq(%q(project in (PROJECT\\\\KEY\") order by created DESC))
          end
        end
      end

      context 'with search param' do
        let(:params) { { search: 'new issue' } }

        it 'builds jql' do
          expect(subject)
            .to eq("project in (#{expected_project_keys}) AND (summary ~ \"new issue\" OR description ~ \"new issue\") order by created DESC")
        end

        context 'search param with single quotes' do
          let(:params) { { search: "new issue's" } }

          it 'builds jql' do
            expect(subject)
              .to eq(%(project in (#{expected_project_keys}) AND (summary ~ "new issue\'s" OR description ~ "new issue\'s") order by created DESC))
          end
        end

        context 'search param with single double qoutes' do
          let(:params) { { search: '"one \"more iss\'ue"' } }

          it 'builds jql' do
            expect(subject)
              .to eq(%(project in (#{expected_project_keys}) AND (summary ~ "one more iss'ue" OR description ~ "one more iss'ue") order by created DESC))
          end
        end

        context 'search param with special characters' do
          let(:params) { { search: 'issues' + Jira::JqlBuilderService::JQL_SPECIAL_CHARS.join(" AND ") } }

          it 'builds jql' do
            expect(subject)
              .to eq(%(project in (#{expected_project_keys}) AND (summary ~ "issues and and and and and and and and and and and and and and and and" OR description ~ "issues and and and and and and and and and and and and and and and and") order by created DESC))
          end
        end
      end

      context 'with labels param' do
        let(:params) { { labels: ['label1', 'label2', "\"'try\"some'more\"quote'here\""] } }

        it 'builds jql' do
          expect(subject)
            .to eq(%(project in (#{expected_project_keys}) AND labels = "label1" AND labels = "label2" AND labels = "\\"'try\\"some'more\\"quote'here\\"" order by created DESC))
        end
      end

      context 'with status param' do
        let(:params) { { status: "\"'try\"some'more\"quote'here\"" } }

        it 'builds jql' do
          expect(subject)
            .to eq(%(project in (#{expected_project_keys}) AND status = "\\"'try\\"some'more\\"quote'here\\"" order by created DESC))
        end
      end

      context 'with author_username param' do
        let(:params) { { author_username: "\"'try\"some'more\"quote'here\"" } }

        it 'builds jql' do
          expect(subject)
            .to eq(%(project in (#{expected_project_keys}) AND reporter = "\\"'try\\"some'more\\"quote'here\\"" order by created DESC))
        end
      end

      context 'with assignee_username param' do
        let(:params) { { assignee_username: "\"'try\"some'more\"quote'here\"" } }

        it 'builds jql' do
          expect(subject)
            .to eq(%(project in (#{expected_project_keys}) AND assignee = "\\"'try\\"some'more\\"quote'here\\"" order by created DESC))
        end
      end

      context 'with sort params' do
        let(:params) { { sort: 'updated', sort_direction: 'ASC' } }

        it 'builds jql' do
          expect(subject).to eq("project in (#{expected_project_keys}) order by updated ASC")
        end
      end

      context 'with opened state param' do
        let(:params) { { state: 'opened' } }

        it 'builds jql' do
          expect(subject).to eq("project in (#{expected_project_keys}) AND statusCategory != Done order by created DESC")
        end
      end

      context 'with closed state param' do
        let(:params) { { state: 'closed' } }

        it 'builds jql' do
          expect(subject).to eq("project in (#{expected_project_keys}) AND statusCategory = Done order by created DESC")
        end
      end

      context 'with any other state param' do
        let(:params) { { state: 'all' } }

        it 'builds jql' do
          expect(subject).to eq("project in (#{expected_project_keys}) order by created DESC")
        end
      end

      context 'with vulnerability_ids params' do
        let(:params) { { vulnerability_ids: %w[1 25] } }

        it 'builds jql' do
          expect(subject).to eq(%(project in (#{expected_project_keys}) AND (description ~ \"\\\"Issue created from vulnerability 1\\\"\" OR description ~ \"/-/security/vulnerabilities/1\" OR description ~ \"\\\"Issue created from vulnerability 25\\\"\" OR description ~ \"/-/security/vulnerabilities/25\") order by created DESC))
        end
      end

      context 'with issue_ids params' do
        let(:params) { { issue_ids: %w[1 25] } }

        it 'builds jql' do
          expect(subject).to eq("project in (#{expected_project_keys}) AND (id = 1 OR id = 25) order by created DESC")
        end
      end
    end

    context 'when project key is empty' do
      let(:project_keys) { '' }
      let(:params) { {} }

      it 'builds jql without project filter' do
        expect(subject).to eq("order by created DESC")
      end
    end

    context 'when a single project key is provided' do
      let(:project_keys) { 'PROJECT_KEY' }

      include_examples 'builds jql'
    end

    context 'when multiple project keys are provided' do
      let(:project_keys) { 'PROJECT_KEY,FOO,BAR' }

      include_examples 'builds jql'
    end
  end
end
