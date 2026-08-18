# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Create::MappingCreator, feature_category: :workspaces do
  include ResultMatchers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:agent) { create(:cluster_agent) }
  let_it_be(:user) { create(:user) }
  let(:context) { { organization: organization, agent: agent, user: user } }

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
  end

  context 'when a mapping exists for the same cluster agent and organization' do
    before do
      described_class.create(context) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
    end

    it 'returns an err Result indicating that a mapping already exists' do
      expect(result).to be_err_result(RemoteDevelopment::Messages::OrganizationClusterAgentMappingAlreadyExists.new)
    end
  end

  # noinspection RubyResolve -- Rubymine isn't finding build_stubbed
  context 'when the mapping creation fails' do
    shared_examples 'err result' do |expected_error_details:|
      it 'does not create the db records and returns an error result containing a failed message with model errors' do
        expect { result }.not_to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }

        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::OrganizationClusterAgentMappingCreateFailed)
          message.content => { errors: ActiveModel::Errors => errors }
          expect(errors.full_messages).to match([/#{expected_error_details}/i])
        end
      end
    end

    context 'when cluster agent does not exist' do
      let_it_be(:agent) { build_stubbed(:cluster_agent) }

      it_behaves_like 'err result', expected_error_details: "Agent can't be blank"
    end

    context 'when organization does not exist' do
      let_it_be(:organization) { build_stubbed(:organization) }

      it_behaves_like 'err result', expected_error_details: "Organization can't be blank"
    end

    context 'when user does not exist' do
      let_it_be(:user) { build_stubbed(:user) }

      it_behaves_like 'err result', expected_error_details: "User can't be blank"
    end
  end

  context 'when a mapping does not exist for the same cluster agent and organization' do
    it 'returns an ok Result containing the recently added mapping' do
      expect(result).to be_ok_result
      expect(result.unwrap).to be_a(RemoteDevelopment::Messages::OrganizationClusterAgentMappingCreateSuccessful)
      new_mapping = result.unwrap.content[:organization_cluster_agent_mapping]

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(new_mapping.cluster_agent_id).to be(agent.id)
      expect(new_mapping.organization_id).to be(organization.id)
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(new_mapping.creator_id).to be(user.id)
    end
  end
end
