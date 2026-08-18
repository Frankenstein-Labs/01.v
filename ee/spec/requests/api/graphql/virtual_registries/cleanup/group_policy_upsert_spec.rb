# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create or update a cleanup policy for a group', feature_category: :virtual_registry do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) { graphql_mutation(:virtual_registries_cleanup_policy_upsert, params) }
  let(:mutation_response) { graphql_mutation_response(:virtual_registries_cleanup_policy_upsert) }
  let(:params) do
    {
      full_path: group.full_path,
      enabled: true,
      keep_n_days_after_download: 56,
      cadence: 30,
      notify_on_success: true,
      notify_on_failure: true
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(VirtualRegistries::Packages::Maven).to receive(:feature_enabled?)
      .and_return(feature_enabled)
  end

  context 'when current_user has permission' do
    let(:feature_enabled) { true }

    before_all do
      group.add_owner(current_user)
    end

    it 'creates cleanup policy for the group' do
      expect { execute }.to change { VirtualRegistries::Cleanup::Policy.for_group(group).count }.by(1)
    end

    context 'when maven virtual registry is not available' do
      let(:feature_enabled) { false }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when params is null' do
      where(:argument_name) do
        [
          [:enabled],
          [:keep_n_days_after_download],
          [:cadence],
          [:notify_on_success],
          [:notify_on_failure]
        ]
      end

      with_them do
        let(:params) { super().merge(argument_name => nil) }
        let(:field_name) { GraphqlHelpers.fieldnamerize(argument_name) }

        it 'returns validation failed error' do
          execute

          expect(graphql_errors[0]['message']).to eq("#{field_name} can't be null")
        end
      end
    end
  end

  context 'when current_user has no permission' do
    let(:feature_enabled) { true }

    before_all do
      group.add_guest(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
