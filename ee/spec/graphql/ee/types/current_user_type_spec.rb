# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::CurrentUserType, feature_category: :user_profile do
  it 'has the expected fields' do
    expected_fields = %w[
      workspaces
      duo_chat_available
      duo_classic_chat_available
      duo_code_suggestions_available
      duo_chat_available_features
      code_suggestions_contexts
      admin
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'workspaces field' do
    subject { described_class.fields['workspaces'] }

    it 'returns workspaces' do
      is_expected.to have_graphql_type(Types::RemoteDevelopment::WorkspaceType.connection_type)
      is_expected.to have_graphql_resolver(Resolvers::RemoteDevelopment::WorkspacesResolver)
    end
  end

  describe 'duoClassicChatAvailable field' do
    subject { described_class.fields['duoClassicChatAvailable'] }

    it 'returns duoClassicChatAvailable' do
      is_expected.to have_graphql_type(GraphQL::Types::Boolean.to_non_null_type)
      is_expected.to have_graphql_resolver(Resolvers::Ai::UserClassicChatAccessResolver)
    end
  end

  describe 'codeSuggestionsContexts field' do
    subject { described_class.fields['codeSuggestionsContexts'] }

    it 'returns codeSuggestionsContexts' do
      is_expected.to have_graphql_type(GraphQL::Types::String)
      is_expected.to have_graphql_resolver(Resolvers::Ai::UserCodeSuggestionsContextsResolver)
    end
  end

  describe 'admin field' do
    subject { described_class.fields['admin'] }

    it 'returns admin flag' do
      is_expected.to have_graphql_type(GraphQL::Types::Boolean.to_non_null_type)
    end
  end
end
