# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::UserAvailableFeaturesResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: current_user }) }

  describe '#resolve' do
    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it 'returns an empty array' do
        expect(resolver).to eq([])
      end
    end

    context 'when user is authenticated' do
      let(:current_user) { user }

      context 'when duo chat is enabled' do
        context 'when user does not have access to duo chat' do
          before do
            allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user,
              :allowed?).and_return(false)
          end

          it 'returns an empty array' do
            expect(resolver).to eq([])
          end
        end

        context 'when user has access to duo chat' do
          before do
            allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user,
              :allowed?).and_return(true)
            allow(current_user).to receive(:allowed_to_use?).and_return(true)
          end

          context 'when all context categories are enabled' do
            before do
              already_enabled_context = %w[file snippet user_rule agent_user_environment repository directory terminal]
              ::Ai::AdditionalContext::DUO_CHAT_CONTEXT_CATEGORIES.each_value do |category|
                next if already_enabled_context.include?(category)

                stub_feature_flags("duo_include_context_#{category}": true)
              end
            end

            it 'returns all available features' do
              expected_features = ::Ai::AdditionalContext::DUO_CHAT_CONTEXT_CATEGORIES.values.map do |category|
                "include_#{category}_context"
              end

              expect(resolver).to match_array(expected_features)
            end
          end

          context 'when testing each context category individually' do
            feature_flags =
              {
                duo_include_context_merge_request: ['include_merge_request_context'],
                duo_include_context_issue: ['include_issue_context'],
                duo_include_context_dependency: ['include_dependency_context'],
                duo_include_context_local_git: ['include_local_git_context']
              }

            let(:default_enabled_features) do
              %w[
                include_file_context
                include_snippet_context
                include_user_rule_context
                include_agent_user_environment_context
                include_repository_context
                include_directory_context
                include_terminal_context
              ]
            end

            feature_flags.each do |flag, ff_enabled_features|
              context "when only #{flag} is enabled" do
                before do
                  feature_flags.each_key { |f| stub_feature_flags(f => false) }
                  stub_feature_flags(flag => true)
                end

                it "returns #{ff_enabled_features} and all already enabled features" do
                  expected_features = ff_enabled_features + default_enabled_features
                  expect(resolver).to match_array(expected_features)
                end
              end
            end
          end
        end
      end
    end
  end
end
