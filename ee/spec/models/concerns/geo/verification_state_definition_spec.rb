# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::VerificationStateDefinition, feature_category: :geo_replication do
  using RSpec::Parameterized::TableSyntax

  include ::EE::GeoHelpers

  before_all do
    create_dummy_model_table
  end

  after(:all) do
    drop_dummy_model_table
  end

  let_it_be(:dummy_model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = '_test_dummy_models'
      def self.name
        'TestDummyModel'
      end
      include Geo::VerificationStateDefinition
    end
  end

  let_it_be(:record1, freeze: true) { dummy_model_class.create! }
  let_it_be_with_reload(:record2) { dummy_model_class.create! }
  let_it_be(:record3, freeze: true) { dummy_model_class.create! }

  let(:dummy_model) { dummy_model_class.new }

  describe '#verification_state_name_no_prefix' do
    where(:raw_state, :expected_result) do
      :verification_pending   | 'pending'
      :verification_started   | 'started'
      :verification_succeeded | 'succeeded'
      :verification_failed    | 'failed'
      :verification_disabled  | 'disabled'
    end

    with_them do
      it 'removes verification_ prefix from state name' do
        dummy_model.verification_state = ::Geo::VerificationState::VERIFICATION_STATE_VALUES[raw_state]

        expect(dummy_model.verification_state_name_no_prefix).to eq(expected_result)
      end
    end
  end

  describe '.after_cursor' do
    context 'when cursor is nil' do
      it 'returns all records' do
        result = dummy_model_class.after_cursor(nil)

        expect(result).to match_array([record1, record2, record3])
      end
    end

    context 'when cursor is provided' do
      it 'returns records with primary key greater than cursor' do
        result = dummy_model_class.after_cursor(record1.id)

        expect(result).to match_array([record2, record3])
      end

      it 'returns empty relation when cursor is greater than all records' do
        max_id = dummy_model_class.maximum(:id)
        result = dummy_model_class.after_cursor(max_id + 1)

        expect(result).to be_empty
      end

      it 'returns all records when cursor is less than minimum id' do
        min_id = dummy_model_class.minimum(:id)
        result = dummy_model_class.after_cursor(min_id - 1)

        expect(result).to match_array([record1, record2, record3])
      end

      it 'handles various cursor types' do
        # String that looks like a number
        expect { dummy_model_class.after_cursor('123') }.not_to raise_error

        # Boolean values
        expect { dummy_model_class.after_cursor(true) }.not_to raise_error
        expect { dummy_model_class.after_cursor(false) }.not_to raise_error

        # Float values
        expect { dummy_model_class.after_cursor(123.45) }.not_to raise_error
      end
    end

    context 'when cursor is zero' do
      it 'returns all records' do
        result = dummy_model_class.after_cursor(0)

        expect(result).to match_array([record1, record2, record3])
      end
    end

    it 'is chainable with other scopes' do
      result = dummy_model_class.after_cursor(record1.id).where(id: record2.id)

      expect(result).to contain_exactly(record2)
    end

    it 'is chainable with verification_state_not_pending scope' do
      record2.update!(verification_state: ::Geo::VerificationState::VERIFICATION_STATE_VALUES[:verification_started])

      result = dummy_model_class.after_cursor(record1.id).verification_state_not_pending

      expect(result).to contain_exactly(record2)
    end

    # Some state tables keep their own surrogate `id` primary key, so the column holding the model
    # id is a different one and callers have to page by that instead.
    context 'when an explicit column is given' do
      it 'pages by that column rather than the primary key' do
        dummy_model_class.create!(verification_retry_count: 5)
        beyond_cursor = dummy_model_class.create!(verification_retry_count: 10)

        result = dummy_model_class.after_cursor(5, :verification_retry_count)

        expect(result).to contain_exactly(beyond_cursor)
      end

      it 'falls back to the primary key when the column is nil' do
        result = dummy_model_class.after_cursor(record1.id, nil)

        expect(result).to match_array([record2, record3])
      end

      it 'returns all records when the cursor is nil, whatever the column' do
        result = dummy_model_class.after_cursor(nil, :verification_retry_count)

        expect(result).to match_array([record1, record2, record3])
      end
    end
  end

  describe '.keyset_order' do
    it 'applies keyset ordering based on provided attributes' do
      order_attributes = [
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: dummy_model_class.arel_table[:id].asc
        )
      ]

      result = dummy_model_class.keyset_order(order_attributes)

      expect(result.to_a).to eq([record1, record2, record3])
    end

    it 'applies descending keyset ordering' do
      order_attributes = [
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: dummy_model_class.arel_table[:id].desc
        )
      ]

      result = dummy_model_class.keyset_order(order_attributes)

      expect(result.to_a).to eq([record3, record2, record1])
    end

    it 'is chainable with other scopes' do
      order_attributes = [
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: dummy_model_class.arel_table[:id].asc
        )
      ]

      result = dummy_model_class.where(id: [record1.id, record3.id]).keyset_order(order_attributes)

      expect(result.to_a).to eq([record1, record3])
    end

    it 'handles empty order attributes gracefully' do
      result = dummy_model_class.keyset_order([])

      expect(result.to_sql).not_to include('ORDER BY')
      expect(result.to_a.size).to eq(3)
    end
  end

  describe '.verification_state_not_pending' do
    let_it_be(:success_record, freeze: true) do
      dummy_model_class.create!(verification_state: 2, verification_checksum: 'abc')
    end

    let_it_be(:failed_record, freeze: true) do
      dummy_model_class.create!(verification_state: 3, verification_failure: 'error')
    end

    it 'excludes records with pending verification state' do
      result = dummy_model_class.verification_state_not_pending

      expect(result).not_to include(record1, record2, record3)
    end

    it 'returns records with non pending state' do
      result = dummy_model_class.verification_state_not_pending

      expect(result).to match_array([success_record, failed_record])
    end

    it 'is chainable with other scopes' do
      result = dummy_model_class.verification_state_not_pending.where(id: failed_record.id)

      expect(result).to contain_exactly(failed_record)
    end
  end

  describe '.verified_after' do
    let(:cutoff) { 2.days.ago.change(usec: 0) }

    let!(:verified_before_cutoff) { dummy_model_class.create!(verified_at: cutoff - 1.day) }
    let!(:verified_at_cutoff) { dummy_model_class.create!(verified_at: cutoff) }
    let!(:verified_after_cutoff) { dummy_model_class.create!(verified_at: cutoff + 1.day) }

    it 'returns records verified at or after the cutoff' do
      expect(dummy_model_class.verified_after(cutoff)).to contain_exactly(
        verified_at_cutoff,
        verified_after_cutoff
      )
    end

    it 'is chainable with verification_state_not_pending scope' do
      verified_after_cutoff.update!(verification_state: 2, verification_checksum: 'abc')

      result = dummy_model_class.verification_state_not_pending.verified_after(cutoff)

      expect(result).to contain_exactly(verified_after_cutoff)
    end
  end

  describe '.with_verification_failure_matching' do
    let_it_be(:missing_file, freeze: true) do
      dummy_model_class.create!(verification_state: 3,
        verification_failure: 'File is not checksummable - file does not exist at: /var/opt/x.png')
    end

    let_it_be(:excluded_from_verification, freeze: true) do
      dummy_model_class.create!(verification_state: 3,
        verification_failure: 'File is not checksummable - Upload 1 is excluded from verification')
    end

    let_it_be(:other_failure, freeze: true) do
      dummy_model_class.create!(verification_state: 3, verification_failure: 'Could not calculate the checksum')
    end

    let_it_be(:succeeded, freeze: true) do
      dummy_model_class.create!(verification_state: 2, verification_checksum: 'abc')
    end

    it 'returns the failed records whose failure includes the pattern, whatever the case' do
      result = dummy_model_class.with_verification_failure_matching('file IS not checksummable')

      expect(result).to contain_exactly(missing_file, excluded_from_verification)
    end

    it 'treats wildcard characters in the pattern literally' do
      dummy_model_class.create!(verification_state: 3, verification_failure: 'a_b')
      literal = dummy_model_class.create!(verification_state: 3, verification_failure: 'a%b')

      expect(dummy_model_class.with_verification_failure_matching('a%b')).to contain_exactly(literal)
    end
  end

  describe '.with_verification_retry_count_at_least' do
    let_it_be(:never_retried, freeze: true) { dummy_model_class.create!(verification_retry_count: nil) }
    let_it_be(:retried_twice, freeze: true) { dummy_model_class.create!(verification_retry_count: 2) }
    let_it_be(:retried_five_times, freeze: true) { dummy_model_class.create!(verification_retry_count: 5) }

    it 'returns records at or above the threshold' do
      expect(dummy_model_class.with_verification_retry_count_at_least(2))
        .to include(retried_twice, retried_five_times)
    end

    it 'excludes records below the threshold' do
      expect(dummy_model_class.with_verification_retry_count_at_least(5)).not_to include(retried_twice)
    end

    # NULL means "no failure recorded yet", so it is excluded even at a threshold of 0. Callers
    # that want no gate at all have to skip the scope rather than pass 0.
    it 'excludes records with no recorded retry count, whatever the threshold' do
      expect(dummy_model_class.with_verification_retry_count_at_least(0)).not_to include(never_retried)
    end

    it 'is chainable with with_verification_failure_matching' do
      persistent = dummy_model_class.create!(
        verification_state: 3, verification_failure: 'boom', verification_retry_count: 5
      )
      dummy_model_class.create!(verification_state: 3, verification_failure: 'boom', verification_retry_count: 1)

      result = dummy_model_class
        .with_verification_failure_matching('boom')
        .with_verification_retry_count_at_least(5)

      expect(result).to contain_exactly(persistent)
    end
  end

  def create_dummy_model_table
    ActiveRecord::Schema.define do
      create_table :_test_dummy_models, force: true do |t|
        t.binary :verification_checksum
        t.integer :verification_state
        t.datetime_with_timezone :verification_started_at
        t.datetime_with_timezone :verified_at
        t.datetime_with_timezone :verification_retry_at
        t.integer :verification_retry_count
        t.text :verification_failure
      end
    end
  end

  def drop_dummy_model_table
    ActiveRecord::Schema.define do
      drop_table :_test_dummy_models, force: true
    end
  end
end
