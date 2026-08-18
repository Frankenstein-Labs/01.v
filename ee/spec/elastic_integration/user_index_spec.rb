# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User Index', :elastic, :sidekiq_inline, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:searching_user) { create(:user) }

  before_all do
    group.add_developer(searching_user)
  end

  def search_users(query, searching_as: searching_user, group_id: group.id)
    options = {
      current_user: searching_as,
      search_level: 'group',
      group_id: group_id,
      autocomplete: true,
      routing_disabled: true,
      admin: searching_as&.can_admin_all_resources?
    }
    User.elastic_search(query, options: options)
  end

  def result_ids(response)
    response.response['hits']['hits'].map { |h| h['_source']['id'] }
  end

  def create_member(name:, username:, public_email: nil)
    create(:user, name: name, username: username).tap do |u|
      u.update_column(:public_email, public_email) if public_email
      group.add_developer(u)
    end
  end

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'dot-separated username with email-style display name' do
    let!(:alex_randall) do
      create_member(
        name: 'Alex.Randall1@corp.example.com',
        username: 'Alex.Randall1',
        public_email: 'Alex.Randall1@corp.example.com'
      )
    end

    let!(:alex_nguyen) { create_member(name: 'Alex Nguyen', username: 'AlexNguyen') }
    let!(:ben_randolph) { create_member(name: 'Ben Randolph', username: 'BenRandolph') }
    let!(:sara_rendell) { create_member(name: 'Sara Rendell', username: 'SaraRendell') }

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'alex randall'  | [:alex_randall]               | [:ben_randolph, :sara_rendell]
      'alex.randall'  | [:alex_randall]               | [:ben_randolph, :sara_rendell]
      'Alex.Randall1' | [:alex_randall]               | []
      'alex.randal'   | [:alex_randall]               | []
      'alex'          | [:alex_randall, :alex_nguyen] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'plain first and last name' do
    let!(:alice_smith) { create_member(name: 'Alice Smith', username: 'alice.smith') }

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'alice smith' | [:alice_smith] | []
      'alice'       | [:alice_smith] | []
      'smith'       | [:alice_smith] | []
      'alice.smith' | [:alice_smith] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'hyphenated last name' do
    let!(:mary) { create_member(name: 'Mary Jones-Brown', username: 'mary.jones-brown') }

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'mary jones-brown' | [:mary] | []
      'mary jones'       | [:mary] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'underscore-separated username' do
    let!(:john_doe) { create_member(name: 'John Doe', username: 'john_doe') }

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'john doe'  | [:john_doe] | []
      'john_doe'  | [:john_doe] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'username with numeric suffix' do
    let!(:jsmith1) { create_member(name: 'Jane Smith', username: 'jsmith1') }
    let!(:jsmith2) { create_member(name: 'James Smith', username: 'jsmith2') }

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'jsmith1' | [:jsmith1]           | []
      'jsmith'  | [:jsmith1, :jsmith2] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'public_email search' do
    let!(:taylor) do
      create_member(name: 'Taylor Ryan', username: 'taylor.ryan', public_email: 'taylor.ryan@example.com')
    end

    before do
      ensure_elasticsearch_index!
    end

    where(:query, :includes, :excludes) do
      'taylor.ryan' | [:taylor] | []
    end

    with_them do
      it 'matches expected users' do
        ids = result_ids(search_users(query))
        expect(ids).to include(*includes.map { |s| public_send(s).id }) if includes.any?
        expect(ids).not_to include(*excludes.map { |s| public_send(s).id }) if excludes.any?
      end
    end
  end

  describe 'namespace visibility filter' do
    let!(:insider) { create_member(name: 'Inside User', username: 'insider_user') }
    let!(:outsider) { create(:user, name: 'Outside User', username: 'outsider_user') }

    before do
      ensure_elasticsearch_index!
    end

    it 'returns group members' do
      expect(result_ids(search_users('inside user'))).to include(insider.id)
    end

    it 'does not return users outside the group' do
      expect(result_ids(search_users('outside user'))).not_to include(outsider.id)
    end
  end
end
