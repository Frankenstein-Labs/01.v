# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Create::MappingCreator, feature_category: :workspaces do
  include ResultMatchers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:agent) { create(:cluster_agent) }
  let_it_be(:user) { create(:user) }
  let(:context) { { namespace: namespace, cluster_agent: agent, user: user } }

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
  end

  context 'when a mapping exists for the same cluster agent and group' do
    before do
      described_class.create(context) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
    end

    it 'returns an err Result indicating that a mapping already exists' do
      expect(result).to be_err_result(RemoteDevelopment::Messages::NamespaceClusterAgentMappingAlreadyExists.new)
    end
  end

  context 'when the mapping creation fails' do
    shared_examples 'err result' do |expected_error_details:|
      it 'does not create the db records and returns an error result containing a failed message with model errors' do
        expect { result }.not_to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }

        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateFailed)
          message.content => { errors: ActiveModel::Errors => errors }
          expect(errors.full_messages).to match([/#{expected_error_details}/i])
        end
      end
    end

    context 'when cluster agent does not exist' do
      # noinspection RubyResolve -- Rubymine isn't finding build_stubbed
      let_it_be(:agent) { build_stubbed(:cluster_agent) }

      it_behaves_like 'err result', expected_error_details: "Agent can't be blank"
    end

    context 'when namespace does not exist' do
      # noinspection RubyResolve -- Rubymine isn't finding build_stubbed
      let_it_be(:namespace) { build_stubbed(:group) }

      it_behaves_like 'err result', expected_error_details: "Namespace can't be blank"
    end

    context 'when user does not exist' do
      # noinspection RubyResolve -- Rubymine isn't finding build_stubbed
      let_it_be(:user) { build_stubbed(:user) }

      it_behaves_like 'err result', expected_error_details: "User can't be blank"
    end
  end

  context 'when a mapping does not exist for the same cluster agent and group' do
    it 'returns an ok Result containing the recently added mapping' do
      expect(result).to be_ok_result
      expect(result.unwrap).to be_a(RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateSuccessful)
      new_mapping = result.unwrap.content[:namespace_cluster_agent_mapping]

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(new_mapping.cluster_agent_id).to be(agent.id)
      expect(new_mapping.namespace_id).to be(namespace.id)
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(new_mapping.creator_id).to be(user.id)
    end
  end
end
