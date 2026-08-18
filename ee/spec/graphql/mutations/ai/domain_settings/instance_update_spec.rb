# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::DomainSettings::InstanceUpdate, :enable_admin_mode, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:ai_settings) do
    create(:ai_settings, allowed_domains: ['example.com', 'gitlab.com'], denied_domains: ['evil.com', 'bad.com'])
  end

  let(:mutation) { described_class.new(object: nil, context: query_context(user: current_user), field: nil) }

  before do
    ai_settings.reload
    allow(::Ai::Setting).to receive(:for_organization).and_return(ai_settings)
  end

  describe '#resolve' do
    context 'when the current user is an admin' do
      let(:current_user) { admin }

      before do
        allow(admin).to receive(:can_admin_all_resources?).and_return(true)
      end

      context 'when adding to allowed domains' do
        it 'appends the new domains and returns the full updated list' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed',
            domains: ['newdomain.com', 'another.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['newdomain.com', 'another.com'])
          expect(result[:removed_domains]).to be_nil
        end

        it 'deduplicates domains that already exist' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed',
            domains: ['example.com', 'newdomain.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['newdomain.com'])
        end

        it 'accepts wildcard domains' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed',
            domains: ['*.google.com', '*.gitlab.stuff.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['*.google.com', '*.gitlab.stuff.com'])
        end
      end

      context 'when adding to denied domains' do
        it 'appends the new domains and returns the full updated list' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'denied', domains: ['blocked.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['blocked.com'])
          expect(result[:removed_domains]).to be_nil
        end
      end

      context 'when removing from allowed domains' do
        it 'removes the specified domains and returns the remaining list' do
          result = mutation.resolve(action: 'remove', domain_setting_type: 'allowed', domains: ['example.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to match_array(['example.com'])
          expect(result[:added_domains]).to be_nil
        end

        it 'ignores domains that do not exist in the list' do
          result = mutation.resolve(action: 'remove', domain_setting_type: 'allowed', domains: ['nonexistent.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to be_empty
        end
      end

      context 'when removing from denied domains' do
        it 'removes the specified domains and returns the remaining list' do
          result = mutation.resolve(action: 'remove', domain_setting_type: 'denied', domains: ['evil.com'])

          expect(result[:errors]).to be_empty
          expect(result[:removed_domains]).to match_array(['evil.com'])
        end
      end

      context 'when domains contain uppercase letters' do
        it 'lowercases domains before saving' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed',
            domains: ['NEWDOMAIN.COM', 'Another.Com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to match_array(['newdomain.com', 'another.com'])
        end

        it 'deduplicates after lowercasing' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed',
            domains: ['EXAMPLE.COM', 'example.com'])

          expect(result[:errors]).to be_empty
          expect(result[:added_domains]).to be_empty
        end
      end

      context 'when adding an invalid domain' do
        it 'returns an error and does not update' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed', domains: ['bad domain'])

          expect(result[:errors]).to include('bad domain is not a valid domain')
          expect(result[:added_domains]).to be_nil
        end
      end

      context 'when the update fails' do
        before do
          allow(ai_settings).to receive(:update).and_return(false)
          allow(ai_settings).to receive_message_chain(:errors, :full_messages).and_return(['is invalid'])
        end

        it 'returns errors and nil domains' do
          result = mutation.resolve(action: 'add', domain_setting_type: 'allowed', domains: ['newdomain.com'])

          expect(result[:added_domains]).to be_nil
          expect(result[:removed_domains]).to be_nil
          expect(result[:errors]).to include('is invalid')
        end
      end
    end

    context 'when the current user is not an admin' do
      let(:current_user) { user }

      it 'raises a resource not available error' do
        expect { mutation.resolve(action: 'add', domain_setting_type: 'allowed', domains: ['example.com']) }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when there is no current user' do
      let(:current_user) { nil }

      it 'raises a resource not available error' do
        expect { mutation.resolve(action: 'add', domain_setting_type: 'allowed', domains: ['example.com']) }
          .to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
