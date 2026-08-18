# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'users', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'users', :elastic_delete_by_query do
    let(:scope) { 'users' }
    let(:query) { 'john' }
    let(:results) { described_class.new(user, query, public_and_internal_projects: true) }
    let_it_be(:user_1) { create(:user, name: 'Sarah John') }
    let_it_be(:user_2) { create(:user, name: 'John Doe', state: :blocked) }
    let_it_be(:user_3) { create(:user, email: 'john@c.o') }

    before do
      ::Elastic::ProcessInitialBookkeepingService.track!(user_1, user_2, user_3)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'users'

    context 'when the user is not allowed to read users' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :read_users_list).and_return(false)
      end

      it 'returns an empty list' do
        expect(results.objects('users')).to be_empty
        expect(results.users_count).to eq 0
      end
    end

    context 'when the user is allowed to read users' do
      it 'lists found users' do
        users = results.objects('users')

        expect(users).to contain_exactly(user_1)
        expect(results.users_count).to eq 1
      end

      context 'when the calling user is an admin' do
        before do
          allow(user).to receive(:can_admin_all_resources?).and_return(true)
        end

        it 'lists found users including blocked user and email match' do
          users = results.objects('users')

          expect(users).to contain_exactly(user_1, user_2, user_3)
          expect(results.users_count).to eq 3
        end
      end
    end
  end
end
