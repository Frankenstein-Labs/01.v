# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe AuditEvents::Streaming::NatsPartitioning, feature_category: :audit_events do
  describe '.partition_for' do
    it 'is deterministic for the same group id' do
      first = described_class.partition_for(12_345)

      expect(described_class.partition_for(12_345)).to eq(first)
    end

    it 'keeps every partition within range', :aggregate_failures do
      [1, 42, 255, 256, 257, 1_000_000, 999_999_999].each do |group_id|
        partition = described_class.partition_for(group_id)

        expect(partition).to be_between(0, described_class::PARTITION_COUNT - 1)
      end
    end

    it 'does not force distinct groups in the same residue class onto one partition' do
      expect(described_class.partition_for(1)).not_to eq(described_class.partition_for(2))
    end

    it 'coerces a numeric string to its integer partition' do
      expect(described_class.partition_for('42')).to eq(described_class.partition_for(42))
    end

    it 'routes only a true nil (instance-scoped) to no numeric partition' do
      expect(described_class.partition_for(nil)).to be_nil
    end

    it 'raises on a non-numeric id rather than silently mispartitioning', :aggregate_failures do
      expect { described_class.partition_for('') }.to raise_error(ArgumentError)
      expect { described_class.partition_for('not-a-number') }.to raise_error(ArgumentError)
      expect { described_class.partition_for('42x') }.to raise_error(ArgumentError)
      expect { described_class.partition_for([42]) }.to raise_error(TypeError)
    end
  end

  describe '.subject_for' do
    it 'builds the partitioned subject for a group' do
      # 42 % 256 == 42, pinned so the test fails if partitioning changes.
      expect(described_class.subject_for(42)).to eq('audit_events.streaming.42')
    end

    it 'wraps a group id whose modulo differs from the raw id' do
      # 300 % 256 == 44, pins the modulo behaviour with a concrete value.
      expect(described_class.subject_for(300)).to eq('audit_events.streaming.44')
    end

    it 'routes a numeric-string group id to the same subject as its integer' do
      expect(described_class.subject_for('42')).to eq(described_class.subject_for(42))
    end

    it 'routes instance-scoped events to the dedicated instance subject' do
      expect(described_class.subject_for(nil)).to eq(described_class::INSTANCE_SUBJECT)
    end

    it 'isolates the instance subject from every numeric partition subject' do
      numeric_subjects = (0...described_class::PARTITION_COUNT).map { |p| described_class.subject_for_partition(p) }

      expect(numeric_subjects).not_to include(described_class::INSTANCE_SUBJECT)
    end
  end

  describe '.partition_keys' do
    it 'lists every numeric partition plus the instance lane', :aggregate_failures do
      keys = described_class.partition_keys

      expect(keys.size).to eq(described_class::PARTITION_COUNT + 1)
      expect(keys.first).to eq(0)
      expect(keys).to include(described_class::PARTITION_COUNT - 1)
      expect(keys.last).to eq(described_class::INSTANCE_KEY)
    end
  end

  describe '.subject_for_key' do
    it 'maps a numeric key to the partition subject' do
      expect(described_class.subject_for_key(7)).to eq('audit_events.streaming.7')
    end

    it 'maps a stringified numeric key the same as its integer (survives arg round-trips)' do
      expect(described_class.subject_for_key('7')).to eq(described_class.subject_for_key(7))
    end

    it 'maps the instance key to the instance subject' do
      expect(described_class.subject_for_key(described_class::INSTANCE_KEY))
        .to eq(described_class::INSTANCE_SUBJECT)
    end

    it 'raises ArgumentError (not TypeError) for an out-of-range or nil key', :aggregate_failures do
      expect { described_class.subject_for_key(described_class::PARTITION_COUNT) }.to raise_error(ArgumentError)
      expect { described_class.subject_for_key(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '.durable_for_key' do
    it 'maps a numeric key to the partition durable' do
      expect(described_class.durable_for_key(7)).to eq('audit_streaming_consumer_7')
    end

    it 'maps a stringified numeric key the same as its integer (survives arg round-trips)' do
      expect(described_class.durable_for_key('7')).to eq(described_class.durable_for_key(7))
    end

    it 'maps the instance key to the instance durable' do
      expect(described_class.durable_for_key(described_class::INSTANCE_KEY))
        .to eq(described_class::INSTANCE_DURABLE)
    end
  end

  describe '.subject_for_partition' do
    it 'builds the subject for a partition index' do
      expect(described_class.subject_for_partition(7)).to eq('audit_events.streaming.7')
    end

    it 'raises for an out-of-range partition', :aggregate_failures do
      expect { described_class.subject_for_partition(-1) }.to raise_error(ArgumentError)
      expect { described_class.subject_for_partition(described_class::PARTITION_COUNT) }
        .to raise_error(ArgumentError)
    end
  end

  describe '.durable_for_partition' do
    it 'builds a per-partition durable name' do
      expect(described_class.durable_for_partition(7)).to eq('audit_streaming_consumer_7')
    end

    it 'raises for an out-of-range partition' do
      expect { described_class.durable_for_partition(described_class::PARTITION_COUNT) }
        .to raise_error(ArgumentError)
    end
  end
end
