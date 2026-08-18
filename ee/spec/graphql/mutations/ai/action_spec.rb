# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Action, feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:resource) { create(:issue) }
  let(:resource_id) { resource.to_gid.to_s }
  let(:request_id) { 'uuid' }
  let(:headers) do
    {
      "Referer" => "foobar",
      "User-Agent" => "user-agent",
      'X-Gitlab-Client-Type' => 'ide',
      'X-Gitlab-Client-Version' => '1.0',
      'X-Gitlab-Client-Name' => 'gitlab-extension',
      'X-Gitlab-Interface' => 'vscode'
    }
  end

  let(:request) { instance_double(ActionDispatch::Request, headers: headers) }
  let(:expected_options) do
    {
      user_agent: "user-agent",
      x_gitlab_client_type: 'ide',
      x_gitlab_client_version: '1.0',
      x_gitlab_client_name: 'gitlab-extension',
      x_gitlab_interface: 'vscode'
    }
  end

  let(:current_user) { user }
  let(:started_at) { 1731398657013 }

  subject(:mutation) do
    described_class.new(object: nil, context: query_context(user: user, request: request), field: nil)
  end

  describe '#ready?' do
    let(:arguments) do
      { summarize_review: { resource_id: resource_id }, client_subscription_id: 'id' }
    end

    it { is_expected.to be_ready(**arguments) }

    context 'when no arguments are set' do
      let(:arguments) { {} }

      it 'raises error' do
        expect { subject.ready?(**arguments) }
          .to raise_error(
            Gitlab::Graphql::Errors::ArgumentError,
            described_class::MUTUALLY_EXCLUSIVE_ARGUMENTS_ERROR
          )
      end
    end
  end

  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end

  describe '#resolve' do
    subject do
      mutation.resolve(**input)
    end

    before do
      allow(::Gitlab::Metrics::System).to receive(:real_time).and_return(started_at)
    end

    shared_examples_for 'an AI action when feature flag disabled' do |feature_flag = :ai_global_switch|
      context 'when the user can perform AI action' do
        before do
          resource.project.add_developer(user)
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(feature_flag => false)
          end

          it 'raises error' do
            expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end
    end

    shared_examples_for 'an AI action' do
      context 'when resource_id is not for an Ai::Model' do
        let(:resource_id) { "gid://gitlab/Note/#{resource.id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
        end
      end

      context 'when resource cannot be found' do
        let(:resource_id) { "gid://gitlab/Issue/#{non_existing_record_id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the action is called too many times' do
        it 'raises error' do
          expect(Gitlab::ApplicationRateLimiter).to(
            receive(:throttled?).with(:ai_action, scope: [user]).and_return(true)
          )

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /too many times/)
        end
      end

      context 'when user cannot read resource' do
        it 'raises error' do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability)
            .to receive(:allowed?)
            .with(user, "read_#{resource.to_ability_name}", resource)
            .and_return(false)

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user can perform AI action' do
        context 'when user is not a member who can view the resource' do
          before do
            allow(Ability)
              .to receive(:allowed?)
              .with(user, "read_#{resource.to_ability_name}", resource)
              .and_return(true)
          end

          it 'calls Llm::ExecuteMethodService' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              resource,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.success(
                  payload: {
                    ai_message: build(:ai_message, request_id: request_id)
                  }))
            end

            expect(subject[:errors]).to be_empty
            expect(subject[:request_id]).to eq(request_id)
          end
        end

        context 'when user is a member who can view the resource' do
          before do
            resource.project.add_developer(user)
          end

          it 'calls Llm::ExecuteMethodService' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              resource,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.success(
                  payload: {
                    ai_message: build(:ai_message, request_id: request_id)
                  }))
            end

            expect(subject[:errors]).to be_empty
            expect(subject[:request_id]).to eq(request_id)
          end

          context 'when Llm::ExecuteMethodService errors out' do
            it 'returns errors' do
              expect_next_instance_of(
                Llm::ExecuteMethodService,
                user,
                resource,
                expected_method,
                expected_options
              ) do |svc|
                expect(svc)
                  .to receive(:execute)
                  .and_return(ServiceResponse.error(message: 'error'))
              end

              expect(subject[:errors]).to eq(['error'])
              expect(subject[:request_id]).to be_nil
            end
          end

          context 'when resource is null' do
            let(:resource_id) { nil }

            it 'calls Llm::ExecuteMethodService' do
              expect_next_instance_of(
                Llm::ExecuteMethodService,
                user,
                nil,
                expected_method,
                expected_options
              ) do |svc|
                expect(svc)
                  .to receive(:execute)
                  .and_return(ServiceResponse.success(
                    payload: {
                      ai_message: build(:ai_message, request_id: request_id)
                    }))
              end

              expect(subject[:errors]).to be_empty
              expect(subject[:request_id]).to eq(request_id)
            end
          end
        end
      end
    end

    context 'when chat input is set' do
      let_it_be(:project) { create(:project, :repository, developers: user) }
      let_it_be(:issue) { create(:issue, project: project) }
      let(:input) { { chat: { resource_id: resource_id } } }
      let(:expected_method) { :chat }
      let(:expected_options) do
        {
          referer_url: "foobar",
          user_agent: "user-agent",
          thread: instance_of(Ai::Conversation::Thread),
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
    end

    context 'when generate_description input is set' do
      let(:input) { { generate_description: { resource_id: resource_id } } }
      let(:expected_method) { :generate_description }
      let(:expected_options) do
        {
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end

    context 'when client_subscription_id input is set' do
      let(:input) { { generate_description: { resource_id: resource_id }, client_subscription_id: 'id' } }
      let(:expected_method) { :generate_description }
      let(:expected_options) do
        {
          client_subscription_id: 'id',
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end

    context 'when platform_origin input is set' do
      let(:input) { { generate_description: { resource_id: resource_id }, platform_origin: 'vs_code_extension' } }
      let(:expected_method) { :generate_description }
      let(:expected_options) do
        {
          user_agent: "user-agent",
          platform_origin: 'vs_code_extension',
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
      it_behaves_like 'an AI action when feature flag disabled'
    end

    context 'when X-Gitlab-Tracking-Context header is set' do
      let(:input) { { generate_description: { resource_id: resource_id } } }
      let(:expected_method) { :generate_description }
      let(:headers) do
        {
          "User-Agent" => "user-agent",
          'X-Gitlab-Client-Type' => 'ide',
          'X-Gitlab-Client-Version' => '1.0',
          'X-Gitlab-Client-Name' => 'Duo CLI',
          'X-Gitlab-Interface' => 'vscode',
          'X-Gitlab-Tracking-Context' => '{"distribution":"npm","execution_environment":"CI"}'
        }
      end

      let(:expected_options) do
        {
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'Duo CLI',
          x_gitlab_interface: 'vscode',
          x_gitlab_tracking_context: '{"distribution":"npm","execution_environment":"CI"}',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
    end

    context 'when conversation type is specified' do
      let_it_be(:user) { create(:user, organizations: [current_organization]) }

      let(:input) { { chat: { resource_id: resource_id }, conversation_type: 'duo_chat' } }
      let(:expected_method) { :chat }
      let(:expected_options) do
        {
          referer_url: "foobar",
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          thread: instance_of(Ai::Conversation::Thread),
          started_at: started_at
        }
      end

      let(:expected_thread) { user.ai_conversation_threads.last }
      let(:expected_thread_id) { expected_thread.to_global_id }

      it_behaves_like 'an AI action'

      it 'creates a thread' do
        resource.project.add_developer(user)

        expect { subject }.to change { user.ai_conversation_threads.in_organization(current_organization).count }.by(1)
      end

      context 'when it fails to create a thread' do
        let(:input) { { chat: { resource_id: resource_id }, conversation_type: 'unknown' } }

        it 'returns error' do
          resource.project.add_developer(user)

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError,
            "Failed to create a thread for unknown.")
        end
      end
    end

    context 'when thread id is specified' do
      let_it_be(:thread) { create(:ai_conversation_thread, user: user, organization: current_organization) }

      let(:input) { { chat: { resource_id: resource_id }, thread_id: thread.to_global_id } }
      let(:expected_method) { :chat }
      let(:expected_options) do
        {
          referer_url: "foobar",
          user_agent: "user-agent",
          thread: thread,
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      let(:expected_thread_id) { thread.to_global_id }

      it_behaves_like 'an AI action'

      it 'does not create a thread' do
        resource.project.add_developer(user)

        expect { subject }.not_to change { user.ai_conversation_threads.in_organization(current_organization).count }
      end

      context 'when thread is not found' do
        let_it_be(:thread) { create(:ai_conversation_thread, user: create(:user)) }

        it 'returns error' do
          resource.project.add_developer(user)

          expect { subject }.to raise_error(
            Gitlab::Graphql::Errors::ArgumentError, "Thread not found. It may have expired."
          )
        end
      end
    end

    context 'when input is set for feature in self-managed' do
      let(:input) { { summarize_review: { resource_id: resource_id }, client_subscription_id: 'id' } }
      let(:expected_method) { :summarize_review }
      let(:expected_options) do
        {
          client_subscription_id: 'id',
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      before do
        stub_const(
          "::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST",
          summarize_review: {
            self_managed: true,
            execute_method: ::Llm::MergeRequests::SummarizeReviewService,
            internal: false
          }
        )
      end

      it_behaves_like 'an AI action'
    end

    context 'when resource is a commit with project ID set' do
      let_it_be(:project) { create(:project, :repository) }

      let(:resource) { project.repository.commit }
      let(:input) { { chat: { resource_id: resource_id }, project_id: project_id } }
      let(:expected_method) { :chat }
      let(:project_id) { resource.project.to_gid.to_s }
      let(:expected_options) do
        {
          user_agent: "user-agent",
          thread: instance_of(Ai::Conversation::Thread),
          project_id: project_id,
          referer_url: "foobar",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability)
          .to receive(:allowed?)
          .with(user, "read_project", resource.project)
          .and_return(true)
      end

      it_behaves_like 'an AI action'
    end

    context 'when explain_vulnerability input is set', :saas do
      before do
        allow(Ability)
            .to receive(:allowed?)
            .and_call_original

        allow(Ability)
            .to receive(:allowed?)
            .with(user, :explain_vulnerability, user)
            .and_return(true)
      end

      let(:input) { { explain_vulnerability: { resource_id: resource_id, include_source_code: true } } }
      let(:expected_method) { :explain_vulnerability }
      let(:expected_options) do
        {
          include_source_code: true,
          user_agent: "user-agent",
          x_gitlab_client_type: 'ide',
          x_gitlab_client_version: '1.0',
          x_gitlab_client_name: 'gitlab-extension',
          x_gitlab_interface: 'vscode',
          started_at: started_at
        }
      end

      it_behaves_like 'an AI action'
    end

    context 'when root_namespace_id is specified' do
      let_it_be(:group) { create(:group) }

      let(:input) { { chat: { resource_id: resource_id }, root_namespace_id: group.to_global_id } }

      before_all do
        resource.project.add_developer(user)
        group.add_developer(user)
      end

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability)
          .to receive(:allowed?)
          .with(user, :read_namespace, group)
          .and_return(true)
      end

      it 'passes the root_namespace_id to the service' do
        expect_next_instance_of(
          Llm::ExecuteMethodService,
          user,
          resource,
          :chat,
          hash_including(root_namespace_id: kind_of(GlobalID))
        ) do |svc|
          expect(svc)
            .to receive(:execute)
            .and_return(ServiceResponse.success(
              payload: {
                ai_message: build(:ai_message, request_id: request_id)
              }))
        end

        result = subject
        expect(result[:errors]).to be_empty
        expect(result[:request_id]).to eq(request_id)
      end

      context 'when resource is null' do
        let(:resource_id) { nil }

        it 'passes the root_namespace_id to the service' do
          expect_next_instance_of(
            Llm::ExecuteMethodService,
            user,
            nil,
            :chat,
            hash_including(root_namespace_id: kind_of(GlobalID))
          ) do |svc|
            expect(svc)
              .to receive(:execute)
              .and_return(ServiceResponse.success(
                payload: {
                  ai_message: build(:ai_message, request_id: request_id)
                }))
          end

          result = subject
          expect(result[:errors]).to be_empty
          expect(result[:request_id]).to eq(request_id)
        end
      end

      context 'when service returns an error' do
        it 'returns the error message' do
          expect_next_instance_of(
            Llm::ExecuteMethodService,
            user,
            resource,
            :chat,
            hash_including(root_namespace_id: kind_of(GlobalID))
          ) do |svc|
            expect(svc)
              .to receive(:execute)
              .and_return(ServiceResponse.error(message: 'error'))
          end

          result = subject
          expect(result[:errors]).to eq(['error'])
          expect(result[:request_id]).to be_nil
        end
      end
    end
  end
end
