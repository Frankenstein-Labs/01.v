# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::DuoWorkflows::ListDuoSessionsService, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(name: 'list_duo_sessions') }

  before do
    service.set_cred(current_user: user)
  end

  describe 'class configuration' do
    it 'registers version 0.1.0' do
      expect(described_class.available_versions).to include('0.1.0')
    end

    it 'documents Chat session exclusion and goal preview truncation', :aggregate_failures do
      description = described_class.version_metadata('0.1.0')[:description]

      expect(description).to include('excluding Duo Chat sessions')
      expect(description).to include('possibly truncated goal preview')
    end

    it 'is registered as an EE GraphQL tool' do
      expect(::EE::Mcp::Tools::Manager::EE_GRAPHQL_TOOLS).to include('list_duo_sessions' => described_class)
    end
  end

  describe 'input schema' do
    it 'uses the canonical workflow status groups and cursor pagination' do
      expect(described_class.version_metadata('0.1.0')[:input_schema]).to eq({
        type: 'object',
        required: [],
        properties: {
          url: {
            type: 'string',
            description: 'GitLab URL of the project to filter sessions by.'
          },
          project_id: {
            type: 'string',
            description: 'Numeric ID or full path of the project to filter sessions by.'
          },
          status_group: {
            type: 'string',
            description: 'Filter by session status group.',
            enum: ::Ai::DuoWorkflows::Workflow::GROUPED_STATUSES.keys.map(&:to_s)
          },
          after: {
            type: 'string',
            description: 'Cursor for forward pagination. Use endCursor from the previous response.'
          },
          first: {
            type: 'integer',
            description: 'Number of sessions to return (forward pagination, default 20, max 100).',
            minimum: 1,
            maximum: 100
          }
        }
      })
    end
  end

  describe '#execute' do
    let(:request) { instance_double(ActionDispatch::Request) }
    let(:params) { { arguments: {} } }

    it 'delegates to the GraphQL tool with the selected version and arguments' do
      expect(Mcp::Tools::DuoWorkflows::ListDuoSessionsTool).to receive(:new).with(
        current_user: user,
        params: params[:arguments],
        version: '0.1.0'
      ).and_call_original

      service.execute(request: request, params: params)
    end

    it 'rejects status group names that do not match the GraphQL enum' do
      result = service.execute(request: request, params: { arguments: { status_group: 'awaiting_approval' } })

      expect(result[:content].first[:text]).to include("Invalid status_group: 'awaiting_approval'")
    end

    it 'rejects status as an unknown argument' do
      result = service.execute(request: request, params: { arguments: { status: 'awaiting_input' } })

      expect(result[:content].first[:text]).to include('status is invalid')
    end

    context 'when current_user is not set' do
      before do
        service.set_cred(current_user: nil)
      end

      it 'returns an error response' do
        result = service.execute(request: request, params: params)

        expect(result).to include(isError: true)
        expect(result[:content].first[:text]).to include('current_user is not set')
      end
    end
  end
end
