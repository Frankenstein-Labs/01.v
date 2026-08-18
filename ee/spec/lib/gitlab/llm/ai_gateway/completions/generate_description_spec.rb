# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::GenerateDescription, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }

  let(:content) { 'issue submit button does not work' }
  let(:description_template_name) { nil }
  let(:ai_options) { { content: content, description_template_name: description_template_name } }
  let(:template_class) { ::Gitlab::Llm::Templates::GenerateDescription }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: %("Success"), success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:prompt_message) do
    build(:ai_message, :generate_description, user: user, resource: issuable, content: content, request_id: uuid)
  end

  let(:tracking_context) { { action: :generate_description, request_id: uuid } }

  let(:expected_template) { nil }

  subject(:generate_description) { described_class.new(prompt_message, template_class, ai_options).execute }

  RSpec.shared_examples 'description generation' do
    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_client)
    end

    it 'executes a completion request and calls the response chains' do
      expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
        user,
        unit_primitive_name: :generate_description,
        tracking_context: tracking_context,
        namespace_id: nil,
        project_id: nil,
        governing_namespace_id: nil
      )
      expect(ai_client).to receive(:complete_prompt).with(
        base_url: Gitlab::AiGateway.url,
        prompt_name: :generate_description,
        inputs: { content: content, template: expected_template },
        model_metadata: nil,
        prompt_version: "^1.0.0",
        timeout: Gitlab::AiGateway.timeout
      ).and_return(ai_response)

      expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

      expect(generate_description[:ai_message].content).to eq("Success")
    end

    context 'with an unsuccessful request' do
      let(:ai_response) { instance_double(HTTParty::Response, body: %("Failed"), success?: false) }

      it 'returns an error' do
        expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          unit_primitive_name: :generate_description,
          tracking_context: tracking_context,
          namespace_id: nil,
          project_id: nil,
          governing_namespace_id: nil
        )
        expect(ai_client).to receive(:complete_prompt).with(
          base_url: Gitlab::AiGateway.url,
          prompt_name: :generate_description,
          inputs: { content: content, template: expected_template },
          model_metadata: nil,
          prompt_version: "^1.0.0",
          timeout: Gitlab::AiGateway.timeout
        ).and_return(ai_response)

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

        expect(generate_description[:ai_message].content).to eq({ "detail" => "An unexpected error has occurred." })
      end
    end
  end

  describe "#execute" do
    context 'for an issue' do
      let_it_be(:issuable) { create(:issue, project: project) }

      it_behaves_like 'description generation'

      context 'with non-existent description template' do
        let(:description_template_name) { 'non-existent' }

        it_behaves_like 'description generation'
      end

      context 'with issue template' do
        let_it_be(:description_template_name) { 'project_issues_template' }
        let_it_be(:template_content) { "project_issues_template content" }
        let_it_be(:project) do
          template_files = {
            ".gitlab/issue_templates/#{description_template_name}.md" => template_content
          }
          create(:project, :custom_repo, files: template_files)
        end

        let_it_be(:issuable) { create(:issue, project: project) }

        let(:expected_template) { template_content }

        it_behaves_like 'description generation'
      end
    end

    context 'for a work item' do
      let_it_be(:issuable) { create(:work_item, :task, project: project) }

      it_behaves_like 'description generation'
    end

    context 'for a merge request' do
      let_it_be(:issuable) { create(:merge_request, source_project: project) }

      it_behaves_like 'description generation'
    end

    context 'for an epic' do
      let_it_be(:issuable) { create(:epic) }

      it_behaves_like 'description generation'
    end
  end
end
