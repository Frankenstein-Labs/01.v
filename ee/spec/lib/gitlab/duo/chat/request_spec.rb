# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Chat::Request, :saas, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user, organization: organization) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:issue) { create(:issue, project: project, iid: 1) }
  let_it_be(:epic) { create(:epic, group: subgroup, iid: 2) }
  let(:completions) { instance_double(::Gitlab::Duo::Chat::Completions) }
  let(:datarow) { ::Gitlab::Duo::Chat::DatasetReader::DataRow.new(ref: 'ref', query: query, resource: resource) }
  let(:response) { instance_double(Gitlab::Llm::Chain::ResponseModifier) }
  let(:response_body) { 'response' }
  let(:answer) { instance_double(Gitlab::Llm::Chain::Answer) }
  let(:context) { instance_double(Gitlab::Llm::Chain::GitlabContext) }
  let(:tools_used) { %w[tool1 tool2] }

  subject(:request) do
    described_class.new({ user_id: current_user.id, root_group_path: group.full_path }).completion(datarow)
  end

  before do
    allow(response).to receive(:ai_response).and_return(answer)
    allow(answer).to receive(:context).and_return(context)
    allow(context).to receive(:tools_used).and_return(tools_used)
    allow(completions).to receive(:execute).and_return(response)
    allow(response).to receive(:response_body).and_return(response_body)
  end

  context 'when the question is about an issue' do
    let(:resource_record) { issue }
    let(:query) { 'What is this issue about?' }
    let(:resource) { described_class::Resource.new(type: 'issue', namespace: project.path, iid: 1, ref: '0') }

    context 'when a tool is used' do
      context 'when the question does not need formatting' do
        it 'finds issue' do
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: tools_used)
        end
      end

      context 'when the question needs formatting' do
        let(:query) { 'Please summarize the current status of the issue %{url}.' }

        it 'formats question with url' do
          url = ::Gitlab::UrlBuilder.build(issue, only_path: false)

          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(query: "Please summarize the current status of the issue #{url}.")
        end
      end
    end

    context 'when a tool is not used' do
      context 'when the response does not respond to :ai_response' do
        it 'returns nil for tools_used' do
          allow(response).to receive(:ai_response).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end

      context 'when the response does not respond to :context' do
        it 'returns nil for tools_used' do
          allow(answer).to receive(:context).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end

      context 'when the response does not respond to :tools_used' do
        it 'returns nil for tools_used' do
          allow(context).to receive(:tools_used).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end
    end
  end

  context 'when the question is about an epic' do
    let(:resource_record) { epic }
    let(:query) { 'What is this epic about?' }
    let(:resource) { described_class::Resource.new(type: 'epic', namespace: subgroup.path, iid: 2, ref: '0') }

    context 'when a tool is used' do
      context 'when the question does not need formatting' do
        it 'finds epic' do
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: tools_used)
        end
      end

      context 'when the question needs formatting' do
        let(:query) { 'Please summarize the current status of the epic %{url}.' }

        it 'formats question with url' do
          url = ::Gitlab::UrlBuilder.build(epic, only_path: false)

          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(query: "Please summarize the current status of the epic #{url}.")
        end
      end
    end

    context 'when a tool is not used' do
      context 'when response does not respond to :ai_response' do
        it 'returns nil for tools_used' do
          allow(response).to receive(:ai_response).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end

      context 'when response does not respond to :context' do
        it 'returns nil for tools_used' do
          allow(answer).to receive(:context).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end

      context 'when response does not respond to :tools_used' do
        it 'returns nil for tools_used' do
          allow(context).to receive(:tools_used).and_return(nil)
          expect(::Gitlab::Duo::Chat::Completions).to receive(:new).with(current_user,
            organization: organization,
            resource: resource_record).and_return(completions)
          expect(request).to include(ref: 'ref', query: query, response: response_body, tools_used: nil)
        end
      end
    end
  end
end
