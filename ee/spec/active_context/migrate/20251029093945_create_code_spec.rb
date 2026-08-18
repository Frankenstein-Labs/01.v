# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/active_context/migrate/20251029093945_create_code.rb')

RSpec.describe CreateCode, feature_category: :code_suggestions do
  let(:version) { 20251029093945 }
  let(:migration) { ::ActiveContext::Migration::Dictionary.instance.find_by_version(version) }
  let(:executor) { instance_double(ActiveContext::Databases::Elasticsearch::Executor, create_collection: true) }
  let(:adapter) { instance_double(ActiveContext::Databases::Elasticsearch::Adapter, executor: executor) }

  subject(:migrate) { migration.new.migrate! }

  it 'creates the code collection' do
    expect(ActiveContext).to receive(:adapter).and_return(adapter)
    expect(executor).to receive(:create_collection).with(:code, hash_including(number_of_partitions: 2))
    migrate
  end

  describe '#number_of_partitions' do
    subject(:number_of_partitions) { described_class.new.number_of_partitions }

    context 'when on GitLab.com' do
      before do
        stub_saas_features(duo_chat_on_saas: true)
      end

      it 'returns 24 partitions' do
        expect(number_of_partitions).to eq(24)
      end
    end

    context 'when not on GitLab.com' do
      before do
        stub_saas_features(duo_chat_on_saas: false)
      end

      context 'with minimal repository data' do
        before do
          allow(Namespace::RootStorageStatistics).to receive(:sum).with(:repository_size).and_return(8.megabytes)
        end

        it 'returns minimum 2 partitions' do
          expect(number_of_partitions).to eq(2)
        end
      end

      context 'with medium repository data' do
        before do
          allow(Namespace::RootStorageStatistics).to receive(:sum).with(:repository_size).and_return(500.gigabytes)
        end

        it 'returns 5 partitions' do
          expect(number_of_partitions).to eq(5)
        end
      end

      context 'with large repository data' do
        before do
          allow(Namespace::RootStorageStatistics).to receive(:sum).with(:repository_size).and_return(1.terabyte)
        end

        it 'returns 11 partitions' do
          expect(number_of_partitions).to eq(11)
        end
      end
    end
  end
end
