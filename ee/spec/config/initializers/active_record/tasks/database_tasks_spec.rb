# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveRecord::Tasks::DatabaseTasks, feature_category: :database do
  let(:db_config) { Gitlab::Database.database_base_models.first }

  it 'does not raise an error' do
    expect { described_class.migrate_status }.not_to raise_error
  end

  describe '.status_with_milestones' do
    let(:missing_version) { 20990101000000 }

    before do
      ApplicationRecord.connection.execute(<<~SQL)
        INSERT INTO schema_migrations (version)
        VALUES (#{ApplicationRecord.connection.quote(missing_version.to_s)})
      SQL
    end

    after do
      ApplicationRecord.connection.execute(<<~SQL)
        DELETE FROM schema_migrations
        WHERE version = (#{ApplicationRecord.connection.quote(missing_version.to_s)})
      SQL
    end

    it 'includes migrated versions without matching migration files' do
      expect(described_class.status_with_milestones).to include([
        'up',
        missing_version.to_s,
        '',
        '',
        '********** NO FILE **********'
      ])
    end
  end
end
