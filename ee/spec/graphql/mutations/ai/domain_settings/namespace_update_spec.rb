# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::DomainSettings::NamespaceUpdate, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let(:mutation) { described_class.new(object: nil, context: query_context(user: current_user), field: nil) }

  before_all do
    root_group.add_owner(owner)
  end

  describe '#resolve' do
    context 'when the current user has admin_group permission' do
      let(:current_user) { owner }

      context 'when adding to allowed domains' do
        before do
          root_group.reload
          root_group.update!(ai_allowed_domains: ['existing.com'])
        end

        it 'appends the new domains and returns the full updated list' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['example.com', 'gitlab.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['example.com', 'gitlab.com'])
          expect(result[:removed_domains]).to be_nil
        end

        it 'deduplicates domains that already exist' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['existing.com', 'newdomain.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['newdomain.com'])
        end

        it 'accepts wildcard domains' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['*.google.com', '*.gitlab.stuff.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['*.google.com', '*.gitlab.stuff.com'])
        end
      end

      context 'when adding to denied domains' do
        before do
          root_group.reload
          root_group.update!(ai_denied_domains: ['blocked.com'])
        end

        it 'appends the new domains and returns the full updated list' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'denied', domains: ['evil.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['evil.com'])
          expect(result[:removed_domains]).to be_nil
        end
      end

      context 'when removing from allowed domains' do
        before do
          root_group.reload
          root_group.update!(ai_allowed_domains: ['example.com', 'gitlab.com'])
        end

        it 'removes the specified domains and returns the remaining list' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'remove', domain_setting_type: 'allowed', domains: ['example.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to match_array(['example.com'])
          expect(result[:added_domains]).to be_nil
        end

        it 'ignores domains that do not exist in the list' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'remove', domain_setting_type: 'allowed', domains: ['nonexistent.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to be_empty
        end
      end

      context 'when removing from denied domains' do
        before do
          root_group.reload
          root_group.update!(ai_denied_domains: ['blocked.com', 'evil.com'])
        end

        it 'removes the specified domains and returns the remaining list' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'remove', domain_setting_type: 'denied', domains: ['blocked.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to match_array(['blocked.com'])
        end
      end

      context 'when domains contain uppercase letters' do
        it 'lowercases domains before saving' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['EXAMPLE.COM', 'GitLab.Com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['example.com', 'gitlab.com'])
        end

        it 'deduplicates after lowercasing' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['EXAMPLE.COM', 'example.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['example.com'])
        end
      end

      context 'when adding an invalid domain' do
        it 'returns an error and does not update' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['bad domain'])

          expect(result[:errors]).to include('bad domain is not a valid domain')
          expect(result[:added_domains]).to be_nil
        end
      end

      context 'when namespace_id refers to a subgroup' do
        before_all do
          subgroup.add_owner(owner)
        end

        it 'raises a resource not available error' do
          expect do
            mutation.resolve(namespace_id: subgroup.to_global_id,
              action: 'add', domain_setting_type: 'allowed', domains: ['example.com'])
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the save fails' do
        before do
          # rubocop:disable RSpec/AnyInstanceOf -- namespace is loaded fresh from DB in the mutation,
          # so we cannot stub a specific instance
          allow_any_instance_of(Ai::NamespaceSetting).to receive(:save).and_return(false)
          allow_any_instance_of(Ai::NamespaceSetting).to receive_message_chain(:errors, :full_messages)
            .and_return(['is invalid'])
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it 'returns errors and nil domains' do
          result = mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['newdomain.com'])

          expect(result[:added_domains]).to be_nil
          expect(result[:removed_domains]).to be_nil
          expect(result[:errors]).to include('is invalid')
        end
      end
    end

    context 'when the current user does not have permission' do
      let(:current_user) { user }

      it 'raises a resource not available error' do
        expect do
          mutation.resolve(namespace_id: root_group.to_global_id,
            action: 'add', domain_setting_type: 'allowed', domains: ['example.com'])
        end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
