# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::GenerateCommitMessage, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) { create(:merge_request) }

  let(:template_class) { ::Gitlab::Llm::Templates::GenerateCommitMessage }
  let(:ai_options) { {} }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: %("Success"), success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:prompt_message) do
    build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
  end

  let(:model_metadata) { { provider: 'gitlab', feature_setting: 'generate_commit_message', identifier: nil } }

  let(:tracking_context) { { action: :generate_commit_message, request_id: uuid } }

  subject(:generate_commit_message) { described_class.new(prompt_message, template_class, ai_options).execute }

  describe "#execute" do
    shared_examples_for 'successful completion request' do
      it 'executes a completion request and calls the response chains' do
        expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          unit_primitive_name: :generate_commit_message,
          tracking_context: tracking_context,
          namespace_id: nil,
          project_id: nil,
          governing_namespace_id: merge_request.target_project.root_ancestor.id
        )
        expect(ai_client).to receive(:complete_prompt).with(
          base_url: Gitlab::AiGateway.url,
          prompt_name: :generate_commit_message,
          inputs: { diff: expected_diff },
          model_metadata: model_metadata,
          prompt_version: expected_prompt_version,
          timeout: Gitlab::AiGateway.timeout
        ).and_return(ai_response)

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

        expect(generate_commit_message[:ai_message].content).to eq("Success")
      end
    end

    let(:expected_diff) { merge_request.raw_diffs.to_a.map(&:diff).join("\n").truncate_words(10000) }
    let(:expected_prompt_version) { "1.2.0" }

    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_client)
    end

    it_behaves_like 'successful completion request'

    context 'on self-managed instance' do
      context 'when instance level model selection feature setting exists' do
        let!(:instance_model_selection_feature_setting) do
          create(:instance_model_selection_feature_setting,
            feature: 'generate_commit_message',
            offered_model_ref: 'claude-3-7-sonnet-20250219')
        end

        it_behaves_like 'successful completion request' do
          let(:model_metadata) do
            { provider: 'gitlab', feature_setting: 'generate_commit_message', identifier: 'claude-3-7-sonnet-20250219' }
          end
        end
      end
    end

    context 'when merge request has empty raw diffs' do
      let(:expected_diff) { '' }

      before do
        allow(merge_request).to receive(:raw_diffs).and_return([])
      end

      it_behaves_like 'successful completion request'
    end

    context 'when merge request diffs is within words limit' do
      let(:expected_diff) { 'a b' }

      before do
        stub_const("#{described_class}::WORDS_LIMIT", 2)

        allow(merge_request)
          .to receive(:raw_diffs)
          .and_return([
            instance_double(
              Gitlab::Git::Diff,
              diff: 'a b'
            )
          ])
      end

      it_behaves_like 'successful completion request'
    end

    context 'when merge request diffs is more than words limit' do
      let(:expected_diff) { 'a b...' }

      before do
        stub_const("#{described_class}::WORDS_LIMIT", 2)

        allow(merge_request)
          .to receive(:raw_diffs)
          .and_return([
            instance_double(
              Gitlab::Git::Diff,
              diff: 'a b c'
            )
          ])
      end

      it_behaves_like 'successful completion request'
    end
  end

  describe 'SAAS only namespace feature setting integration', :saas do
    shared_examples 'calls the AIGW client' do
      let(:expected_diff) do
        merge_request.raw_diffs.to_a.map(&:diff).join("\n").truncate_words(described_class::WORDS_LIMIT)
      end

      it 'sends the correct parameters to the client' do
        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :generate_commit_message,
              inputs: { diff: expected_diff },
              model_metadata: hash_including(
                feature_setting: 'generate_commit_message',
                identifier: expected_identifier,
                provider: 'gitlab'
              ),
              prompt_version: expected_prompt_version,
              timeout: Gitlab::AiGateway.timeout
            )
            .and_return(ai_response)
        end

        generate_commit_message
      end
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:target_project) { create(:project, :small_repo, namespace: group) }
    let_it_be(:merge_request) { create(:merge_request, target_project: target_project, source_project: target_project) }

    before_all do
      group.add_developer(user)
    end

    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_client)
    end

    context 'when namespace has specific feature settings' do
      let!(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: group,
          feature: 'generate_commit_message',
          offered_model_ref: 'claude_sonnet_4_20250514',
          offered_model_name: 'Claude Sonnet 4.0 20250514')
      end

      it_behaves_like 'calls the AIGW client' do
        let(:expected_identifier) { 'claude_sonnet_4_20250514' }
        let(:expected_prompt_version) { '1.2.0' }
      end
    end

    context 'when namespace has no specific feature settings' do
      it_behaves_like 'calls the AIGW client' do
        let(:expected_identifier) { nil }
        let(:expected_prompt_version) { '1.2.0' }
      end
    end
  end

  describe '#prompt_version' do
    let(:completion_instance) { described_class.new(prompt_message, template_class, ai_options) }

    context 'when Amazon Q is enabled' do
      before do
        allow(Ai::AmazonQ).to receive(:enabled?).and_return(true)
      end

      it 'returns the Amazon Q prompt version' do
        expect(completion_instance.prompt_version).to eq('amazon_q/1.0.0')
      end
    end

    context 'when Amazon Q is not enabled' do
      before do
        allow(Ai::AmazonQ).to receive(:enabled?).and_return(false)
      end

      it 'returns the default prompt version' do
        expect(completion_instance.prompt_version).to eq('1.2.0')
      end
    end
  end

  describe '#root_namespace' do
    let(:completion_instance) { described_class.new(prompt_message, template_class, ai_options) }

    context 'when target project has a root ancestor' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:target_project) { create(:project, :small_repo, namespace: subgroup) }

      let(:merge_request) { instance_double(MergeRequest, target_project: target_project) }
      let(:prompt_message) do
        build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
      end

      it 'returns the root ancestor of the target project' do
        expect(completion_instance.root_namespace).to eq(group)
      end
    end

    context 'when target project is at root level' do
      let_it_be(:group) { create(:group) }
      let_it_be(:target_project) { create(:project, :small_repo, namespace: group) }

      let(:merge_request) { instance_double(MergeRequest, target_project: target_project) }
      let(:prompt_message) do
        build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
      end

      it 'returns the group itself' do
        expect(completion_instance.root_namespace).to eq(group)
      end
    end

    context 'when target project belongs to a user namespace' do
      let_it_be(:target_project) { create(:project, :small_repo) }

      let(:merge_request) { instance_double(MergeRequest, target_project: target_project) }
      let(:prompt_message) do
        build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
      end

      it 'returns the user namespace as root ancestor' do
        expect(completion_instance.root_namespace).to eq(target_project.root_namespace)
      end
    end

    context 'when target project is nil' do
      let(:merge_request) { instance_double(MergeRequest, target_project: nil) }
      let(:prompt_message) do
        build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
      end

      it 'returns nil' do
        expect(completion_instance.root_namespace).to be_nil
      end
    end
  end
end
