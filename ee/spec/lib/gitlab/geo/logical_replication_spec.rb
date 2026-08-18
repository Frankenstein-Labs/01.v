# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::LogicalReplication, feature_category: :geo_replication do
  describe '.active?' do
    using RSpec::Parameterized::TableSyntax

    subject(:active?) { described_class.active? }

    where(:configured?, :subscribed?, :expected) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(described_class).to receive_messages(configured?: configured?, database_subscribed?: subscribed?)
      end

      it { is_expected.to be(expected) }
    end
  end

  describe '.database_subscribed?' do
    subject(:database_subscribed?) { described_class.database_subscribed? }

    let(:subscription_query) do
      <<~SQL
        SELECT EXISTS (
          SELECT 1 FROM pg_catalog.pg_subscription s
          JOIN pg_catalog.pg_database d ON d.oid = s.subdbid
          WHERE d.datname = current_database()
        )
      SQL
    end

    before do
      described_class.clear_memoization(:database_subscribed)
    end

    context 'when there are active subscriptions' do
      it 'returns true' do
        expect(ApplicationRecord.connection)
          .to receive(:select_value).with(subscription_query).and_return(true)
        expect(database_subscribed?).to be(true)
      end
    end

    context 'when there are no subscriptions' do
      it 'returns false' do
        expect(ApplicationRecord.connection)
          .to receive(:select_value).with(subscription_query).and_return(false)
        expect(database_subscribed?).to be(false)
      end
    end

    context 'when the database connection is unavailable' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it { is_expected.to be(false) }

      it 'logs an error' do
        expect(Gitlab::Geo::Logger).to receive(:error)

        database_subscribed?
      end
    end

    context 'when the database connection failed' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionFailed)
      end

      it { is_expected.to be(false) }

      it 'logs an error' do
        expect(Gitlab::Geo::Logger).to receive(:error)

        database_subscribed?
      end
    end

    context 'when the query fails' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value).and_raise(ActiveRecord::StatementInvalid)
      end

      it { is_expected.to be(false) }

      it 'logs an error' do
        expect(Gitlab::Geo::Logger).to receive(:error)

        database_subscribed?
      end
    end

    context 'when an unexpected error is raised' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value).and_raise(RuntimeError, 'unexpected')
      end

      it 'is not rescued' do
        expect { database_subscribed? }.to raise_error(RuntimeError, 'unexpected')
      end
    end
  end

  describe '.configured?' do
    using RSpec::Parameterized::TableSyntax

    subject(:configured?) { described_class.configured? }

    where(:secondary?, :flag_enabled?, :expected) do
      true  | true  | true
      true  | false | false
      false | true  | false
      false | false | false
    end

    with_them do
      before do
        allow(Gitlab::Geo).to receive_messages(secondary?: secondary?,
          postgresql_replication_agnostic_enabled?: flag_enabled?)
      end

      it { is_expected.to be(expected) }
    end
  end
end
