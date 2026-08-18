# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::References::User, :elastic_helpers, feature_category: :global_search do
  let_it_be(:user) { create(:user, :admin, :public_email) }

  describe '.serialize' do
    it 'returns a serialized string with the user id' do
      result = described_class.serialize(user)

      expect(result).to eq("User|#{user.id}")
    end
  end

  describe '.instantiate' do
    it 'returns a User reference with the correct identifier and database_id' do
      string = described_class.serialize(user)
      ref = described_class.instantiate(string)

      expect(ref).to be_a(described_class)
      expect(ref.identifier).to eq("user_#{user.id}")
      expect(ref.database_id).to eq(user.id)
    end
  end

  describe '.preload_indexing_data' do
    it 'sets database_record on each ref' do
      ref = described_class.new(user.id)
      described_class.preload_indexing_data([ref])

      expect(ref.database_record).to eq(user)
    end

    it 'sets database_record to nil for missing users' do
      ref = described_class.new(non_existing_record_id)
      described_class.preload_indexing_data([ref])

      expect(ref.database_record).to be_nil
    end

    it 'does not issue additional queries when database_record is accessed after preload' do
      ref = described_class.new(user.id)
      described_class.preload_indexing_data([ref])

      expect { ref.database_record }.not_to exceed_query_limit(0)
    end
  end

  describe '.index' do
    it 'returns the environment-scoped users index name' do
      expect(described_class.index).to include('users')
    end
  end

  describe '.model_klass' do
    it { expect(described_class.model_klass).to eq(::User) }
  end

  describe '#serialize' do
    it 'produces a string that can be reinstantiated' do
      ref = described_class.new(user.id)

      expect(ref.serialize).to eq("User|#{user.id}")
    end
  end

  describe '#operation' do
    context 'when database_record exists' do
      it 'returns :index' do
        ref = described_class.new(user.id)
        ref.database_record = user

        expect(ref.operation).to eq(:index)
      end
    end

    context 'when database_record is nil' do
      it 'returns :delete' do
        ref = described_class.new(non_existing_record_id)
        ref.database_record = nil

        expect(ref.operation).to eq(:delete)
      end
    end
  end

  describe '#as_indexed_json' do
    let(:user_reference) do
      described_class.new(user.id).tap { |r| r.database_record = user.reload }
    end

    subject(:indexed_json) { user_reference.as_indexed_json.with_indifferent_access }

    it 'contains the expected mappings' do
      user_proxy = Elastic::Latest::ApplicationClassProxy.new(User, use_separate_indices: true)
      expected_keys = user_proxy.mappings.to_hash[:properties].keys.map(&:to_s)

      expect(indexed_json.keys).to match_array(expected_keys)
    end

    it 'serializes user as a hash' do
      expect(indexed_json).to include(
        'id' => user.id,
        'username' => user.username,
        'email' => user.email,
        'public_email' => user.public_email,
        'name' => user.name,
        'admin' => true,
        'state' => 'active',
        'external' => false,
        'organization' => user.company,
        'timezone' => user.timezone,
        'in_forbidden_state' => false,
        'status' => nil,
        'status_emoji' => nil,
        'busy' => false,
        'namespace_ancestry_ids' => [],
        'schema_version' => described_class::SCHEMA_VERSION,
        'type' => 'user'
      )
    end

    context 'when user has a status' do
      let_it_be(:user_with_status) do
        u = create(:user)
        create(:user_status, :busy, user: u)
        u
      end

      let(:user_reference) do
        described_class.new(user_with_status.id).tap { |r| r.database_record = user_with_status.reload }
      end

      it 'sets status fields' do
        expect(indexed_json).to include(
          'status' => user_with_status.status.message,
          'status_emoji' => user_with_status.status.emoji,
          'busy' => true
        )
      end
    end

    context 'when user is in a forbidden state' do
      let_it_be(:blocked_user) { create(:user, :blocked) }

      let(:user_reference) do
        described_class.new(blocked_user.id).tap { |r| r.database_record = blocked_user }
      end

      it 'sets in_forbidden_state to true' do
        expect(indexed_json['in_forbidden_state']).to be(true)
      end
    end

    context 'when user is a project member' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }

      let(:user_reference) do
        described_class.new(user.id).tap { |r| r.database_record = user.reload }
      end

      before_all do
        project.add_developer(user)
      end

      it 'includes namespace ancestry ids' do
        expect(indexed_json['namespace_ancestry_ids']).not_to be_empty
      end
    end
  end

  describe '#index_name' do
    it 'delegates to the class index' do
      ref = described_class.new(user.id)

      expect(ref.index_name).to eq(described_class.index)
    end
  end
end
