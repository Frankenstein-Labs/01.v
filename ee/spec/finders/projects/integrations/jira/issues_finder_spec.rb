# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Integrations::Jira::IssuesFinder, feature_category: :team_planning do
  let_it_be_with_refind(:project) { create(:project) }

  let(:jira_integration) { create(:jira_integration, :jira_cloud, project: project) }

  let(:params) { {} }
  let(:service) { described_class.new(project, params) }
  let(:client) { double(options: { site: 'https://jira.example.com' }) }

  before do
    stub_licensed_features(jira_issues_integration: true)
    jira_integration
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    context 'when jira service integration is not active' do
      before do
        jira_integration.update!(active: false)
      end

      it 'raises error' do
        expect { execute_service }.to raise_error(
          Projects::Integrations::Jira::IssuesFinder::IntegrationError,
          'Jira service not configured.'
        )
      end
    end

    context 'when jira service integration is active' do
      before do
        expect_next_instance_of(Jira::Requests::Issues::CloudListService) do |instance|
          expect(instance).to receive(:client).at_least(:once).and_return(client)
        end
      end

      context 'when Jira API request fails' do
        before do
          expect(client).to receive(:get).and_raise(Timeout::Error)
        end

        it 'raises error', :aggregate_failures do
          expect { execute_service }.to raise_error(
            Projects::Integrations::Jira::IssuesFinder::RequestError
          )
        end
      end

      context 'when Jira API request succeeds' do
        before do
          expect(client).to receive(:get).and_return(
            {
              "issues" => [{ "key" => 'TEST-1' }, { "key" => 'TEST-2' }],
              "isLast" => false,
              "nextPageToken" => "token123"
            }
          )
        end

        it 'return service response with issues', :aggregate_failures do
          execute_service

          expect(service.issues.size).to eq 2
          expect(service.issues.map(&:key)).to eq(%w[TEST-1 TEST-2])
        end

        it 'sets Cloud pagination attributes' do
          execute_service

          expect(service.next_page_token).to eq 'token123'
          expect(service.is_last).to be false
        end

        context 'when sorting' do
          shared_examples 'maps sort values' do
            it 'passes correct sort values to JqlBuilderService' do
              expect(::Jira::JqlBuilderService).to receive(:new)
                .with(jira_integration.project_keys_as_string, expected_sort_values)
                .and_call_original

              execute_service
            end
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'created_date' } }
            let(:expected_sort_values) { { sort: 'created', sort_direction: 'DESC' } }
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'created_desc' } }
            let(:expected_sort_values) { { sort: 'created', sort_direction: 'DESC' } }
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'created_asc' } }
            let(:expected_sort_values) { { sort: 'created', sort_direction: 'ASC' } }
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'updated_desc' } }
            let(:expected_sort_values) { { sort: 'updated', sort_direction: 'DESC' } }
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'updated_asc' } }
            let(:expected_sort_values) { { sort: 'updated', sort_direction: 'ASC' } }
          end

          it_behaves_like 'maps sort values' do
            let(:params) { { sort: 'unknown_sort' } }
            let(:expected_sort_values) { { sort: 'created', sort_direction: 'DESC' } }
          end
        end

        context 'when pagination params used' do
          let(:params) { { next_page_token: 'abc123', per_page: '20' } }

          it 'passes them to JqlBuilderService' do
            expect(::Jira::JqlBuilderService).to receive(:new)
              .with(jira_integration.project_keys_as_string, include({ next_page_token: 'abc123', per_page: '20' }))
              .and_call_original

            execute_service
          end
        end
      end
    end

    context 'when filtering by project' do
      let(:params) { { project: 'TEST1' } }

      context 'when project_keys are present' do
        before do
          jira_integration.update!(project_keys: %w[TEST1 TEST2])
        end

        context 'when project_keys does not include project filter' do
          let(:params) { { project: 'TEST3' } }

          it 'returns empty issues' do
            expect(execute_service).to eq []
          end
        end

        context 'when project_keys includes project filter' do
          before do
            expect_next_instance_of(Jira::Requests::Issues::CloudListService) do |instance|
              expect(instance).to receive(:client).at_least(:once).and_return(client)
            end
            expect(client).to receive(:get).and_return(
              {
                "issues" => [{ "key" => 'TEST-1' }, { "key" => 'TEST-2' }],
                "isLast" => true,
                "nextPageToken" => nil
              }
            )
          end

          it 'passes the project filter to JqlBuilderService' do
            expect(::Jira::JqlBuilderService).to receive(:new)
              .with('TEST1', include({ sort: 'created', sort_direction: 'DESC' }))
              .and_call_original

            execute_service
          end
        end
      end

      context 'when project_keys are empty' do
        before do
          expect_next_instance_of(Jira::Requests::Issues::CloudListService) do |instance|
            expect(instance).to receive(:client).at_least(:once).and_return(client)
          end
          expect(client).to receive(:get).and_return(
            {
              "issues" => [{ "key" => 'TEST-1' }, { "key" => 'TEST-2' }],
              "isLast" => true,
              "nextPageToken" => nil
            }
          )
        end

        it 'passes the project filter to JqlBuilderService' do
          expect(::Jira::JqlBuilderService).to receive(:new)
            .with('TEST1', include({ sort: 'created', sort_direction: 'DESC' }))
            .and_call_original

          execute_service
        end
      end
    end

    context 'when filtering by vulnerability_ids' do
      let(:params) { { vulnerability_ids: ['123'] } }

      context 'when jira service integration does not have project_key' do
        it 'raises error' do
          expect { execute_service }.to raise_error(
            Projects::Integrations::Jira::IssuesFinder::IntegrationError,
            'Jira project key is not configured.'
          )
        end
      end

      context 'when jira service integration has project_key' do
        before do
          jira_integration.update!(project_key: 'TEST')
          expect_next_instance_of(Jira::Requests::Issues::CloudListService) do |instance|
            expect(instance).to receive(:client).at_least(:once).and_return(client)
          end
          expect(client).to receive(:get).and_return(
            {
              "issues" => [{ "key" => 'TEST-1' }, { "key" => 'TEST-2' }],
              "isLast" => true,
              "nextPageToken" => nil
            }
          )
        end

        it 'passes the project_key to JqlBuilderService' do
          expect(::Jira::JqlBuilderService).to receive(:new)
            .with('TEST', include({ sort: 'created', sort_direction: 'DESC', vulnerability_ids: ['123'] }))
            .and_call_original

          execute_service
        end
      end
    end

    context 'when jira_issues_integration licensed feature is not available' do
      it 'exits early and returns no issues' do
        stub_licensed_features(jira_issues_integration: false)

        expect(execute_service).to eq []
      end
    end
  end

  context 'with Jira Server deployment' do
    let(:jira_integration) { create(:jira_integration, :jira_server, project: project) }

    describe '#execute' do
      before do
        expect_next_instance_of(Jira::Requests::Issues::ServerListService) do |instance|
          expect(instance).to receive(:client).at_least(:once).and_return(client)
        end

        expect(client).to receive(:get).and_return(
          {
            "total" => 375,
            "startAt" => 0,
            "issues" => [{ "key" => 'TEST-1' }, { "key" => 'TEST-2' }]
          }
        )
      end

      it 'returns total_count for Server deployment' do
        service.execute

        expect(service.total_count).to eq 375
      end

      context 'when pagination params used' do
        let(:params) { { page: '10', per_page: '20' } }

        it 'passes Server pagination params' do
          expect(::Jira::JqlBuilderService).to receive(:new)
            .with(jira_integration.project_keys_as_string, include({ page: '10', per_page: '20' }))
            .and_call_original

          service.execute
        end
      end
    end

    context 'when feature unavailable' do
      it 'returns nil total_count' do
        stub_licensed_features(jira_issues_integration: false)

        service.execute

        expect(service.total_count).to be_nil
      end
    end
  end
end
