# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::ActivityStatWriteBuffer, :clean_gitlab_redis_shared_state,
  feature_category: :dependency_firewall do
  let(:buffer) { described_class.new(buffer_key: 'test_activity_stats') }
  let(:hour) { Time.current.utc.beginning_of_hour }

  def bucket(rule_id: 7, project_id: 42, stat_time: hour, outcome: 0)
    {
      dependency_firewall_policy_rule_id: rule_id,
      project_id: project_id,
      stat_time: stat_time,
      outcome: outcome
    }
  end

  def drain(limit = 10)
    buffer.stage!
    buffer.staged_batch(limit)
  end

  describe 'key expiry' do
    def ttl_of(key)
      Gitlab::Redis::SharedState.with { |r| r.ttl(key) }
    end

    it 'sets a TTL on the live key, which SharedState does not do by default' do
      buffer.add(bucket)

      expect(ttl_of(buffer.send(:buffer_key))).to be_within(60).of(described_class::KEY_TTL.to_i)
    end

    it 'refreshes the live TTL on each write, so a busy buffer is never dropped mid-use' do
      buffer.add(bucket)
      Gitlab::Redis::SharedState.with { |r| r.expire(buffer.send(:buffer_key), 60) }

      buffer.add(bucket)

      expect(ttl_of(buffer.send(:buffer_key))).to be_within(60).of(described_class::KEY_TTL.to_i)
    end

    it 'sets a TTL on the staged key, so an abandoned buffer does not persist indefinitely' do
      buffer.add(bucket)
      buffer.stage!

      expect(ttl_of(buffer.send(:staged_key))).to be_within(60).of(described_class::KEY_TTL.to_i)
    end

    it 'refreshes the staged TTL on each stage, so merged counts do not inherit a short expiry' do
      buffer.add(bucket)
      buffer.stage!
      Gitlab::Redis::SharedState.with { |r| r.expire(buffer.send(:staged_key), 60) }

      buffer.add(bucket)
      buffer.stage!

      expect(ttl_of(buffer.send(:staged_key))).to be_within(60).of(described_class::KEY_TTL.to_i)
    end

    it 'leaves no key behind once the staged entries are removed' do
      buffer.add(bucket)
      buffer.stage!
      buffer.remove_staged(buffer.staged_batch(10))

      # -2 is Redis for "key does not exist"
      expect(ttl_of(buffer.send(:staged_key))).to eq(-2)
    end
  end

  describe 'Redis Cluster key placement' do
    it 'gives the live and staged keys the same hash tag so they share a slot', :aggregate_failures do
      tag = ->(key) { key[/\{(.+?)\}/, 1] }

      live = buffer.send(:buffer_key)
      staged = buffer.send(:staged_key)

      expect(tag.call(live)).to be_present
      expect(tag.call(staged)).to eq(tag.call(live))
    end
  end

  describe '#add' do
    it 'accumulates repeat activity into a single bucket rather than one entry per event' do
      3.times { buffer.add(bucket) }

      expect(drain).to contain_exactly(
        hash_including(dependency_firewall_policy_rule_id: 7, project_id: 42, outcome: 0, count: 3)
      )
    end

    it 'keeps separate buckets per outcome' do
      buffer.add(bucket(outcome: 0))
      buffer.add(bucket(outcome: 1))

      expect(drain).to contain_exactly(hash_including(outcome: 0, count: 1), hash_including(outcome: 1, count: 1))
    end

    it 'keeps separate buckets per hour' do
      buffer.add(bucket(stat_time: hour))
      buffer.add(bucket(stat_time: hour - 1.hour))

      expect(drain.map { |row| row[:stat_time] })
        .to contain_exactly(be_like_time(hour), be_like_time(hour - 1.hour))
    end

    it 'round-trips a nil rule_id, which is how allowed-with-no-match is recorded' do
      2.times { buffer.add(bucket(rule_id: nil, outcome: 2)) }

      expect(drain).to contain_exactly(
        hash_including(dependency_firewall_policy_rule_id: nil, outcome: 2, count: 2)
      )
    end

    it 'does not conflate buckets that differ only by a nil vs present rule_id' do
      buffer.add(bucket(rule_id: nil, outcome: 2))
      buffer.add(bucket(rule_id: 7, outcome: 0))

      expect(drain.map { |row| row[:dependency_firewall_policy_rule_id] }).to contain_exactly(nil, 7)
    end

    it 'rejects an array of buckets, which the list-shaped parent would have accepted' do
      expect { buffer.add([bucket, bucket]) }.to raise_error(ArgumentError)
    end

    it 'fails loudly on a wrong rule id key instead of silently bucketing under a NULL rule' do
      expect { buffer.add(rule_id: 7, project_id: 42, stat_time: hour, outcome: 0) }
        .to raise_error(KeyError)
    end
  end

  describe '#stage!' do
    it 'clears the live buffer so concurrent activity starts a fresh bucket' do
      buffer.add(bucket)
      buffer.stage!
      buffer.add(bucket)

      # The staged copy still holds the first increment; the second is live and not yet staged.
      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(count: 1))
    end

    it 'merges into counts left staged by an earlier failed flush instead of overwriting them' do
      buffer.add(bucket)
      buffer.stage!

      2.times { buffer.add(bucket) }
      buffer.stage!

      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(count: 3))
    end

    it 'is a no-op when nothing has been buffered', :aggregate_failures do
      expect { buffer.stage! }.not_to raise_error
      expect(buffer.staged_batch(10)).to eq([])
    end
  end

  describe '#pop' do
    it 'is not supported, since this buffer is hash-shaped rather than a list' do
      expect { buffer.pop(10) }.to raise_error(NotImplementedError)
    end
  end

  describe '#staged_batch' do
    it 'returns an empty array when nothing is staged' do
      expect(buffer.staged_batch(10)).to eq([])
    end

    it 'does not remove what it returns, so counts survive a crash before the write commits',
      :aggregate_failures do
      buffer.add(bucket)
      buffer.stage!

      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(count: 1))
      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(count: 1))
    end

    it 'honours the limit' do
      3.times { |i| buffer.add(bucket(project_id: i)) }
      buffer.stage!

      expect(buffer.staged_batch(2).size).to eq(2)
    end

    it 'preserves the hour bucket recorded at increment time' do
      buffer.add(bucket(stat_time: hour))

      expect(drain.first[:stat_time]).to be_like_time(hour)
    end
  end

  describe '#remove_staged' do
    it 'clears only the rows it is given' do
      buffer.add(bucket(project_id: 1))
      buffer.add(bucket(project_id: 2))
      buffer.stage!

      rows = buffer.staged_batch(10)
      buffer.remove_staged(rows.select { |row| row[:project_id] == 1 })

      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(project_id: 2))
    end

    it 'leaves the staged hash empty once everything is removed' do
      buffer.add(bucket)
      buffer.stage!

      buffer.remove_staged(buffer.staged_batch(10))

      expect(buffer.staged_batch(10)).to eq([])
    end

    it 'keeps counts staged by a concurrent flush instead of discarding the whole bucket' do
      2.times { buffer.add(bucket) }
      buffer.stage!
      rows = buffer.staged_batch(10)

      # A lapsed lease lets the next run stage more activity into the same field before this run
      # clears it. Only the amount actually written may be removed.
      3.times { buffer.add(bucket) }
      buffer.stage!

      buffer.remove_staged(rows)

      expect(buffer.staged_batch(10)).to contain_exactly(hash_including(count: 3))
    end

    it 'does nothing when given no rows' do
      expect { buffer.remove_staged([]) }.not_to raise_error
    end
  end
end
