# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::GitlabCreditsUnavailableReasonResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it 'returns the AiCreditsDenialReason enum type' do
    expect(described_class.type).to eq(Types::Ai::CreditsDenialReasonEnum)
  end

  it 'accepts a namespace_id argument' do
    expect(described_class.arguments).to have_key('namespaceId')
  end

  it 'authorizes read_namespace' do
    expect(described_class).to require_graphql_authorizations(:read_namespace)
  end

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let(:ctx) { { current_user: user } }

    subject(:resolver) { resolve(described_class, args: args, ctx: ctx) }

    context 'when namespace_id is provided but namespace does not exist' do
      let(:args) { { namespace_id: "gid://gitlab/Namespace/#{non_existing_record_id}" } }

      it 'returns a resource not available error' do
        expect(resolver).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
