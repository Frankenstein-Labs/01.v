# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDuoWorkflow::ExecutionScripts,
  :clean_gitlab_redis_shared_state,
  feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }

  let(:redis) { Gitlab::Redis::SharedState }
  let(:redis_metadata) { redis.with { |r| r.hgetall(keys[:metadata]) } }
  let(:execution_id) { SecureRandom.uuid }
  let(:existing_execution_id) { SecureRandom.uuid }
  let(:project_id) { project.id }
  let(:workflow) { 'remediation' }
  let(:batch_size) { 100 }
  let(:ttl) { 1.hour }
  let(:metadata) { { 'source' => 'spec' } }
  let(:stages) do
    [
      { name: 'critical', order: 0 },
      { name: 'high', order: 1 }
    ]
  end

  let(:keys) do
    {
      metadata: '{test:bulk_duo_workflow}:metadata',
      current: '{test:bulk_duo_workflow}:current',
      latest: '{test:bulk_duo_workflow}:latest'
    }
  end

  subject(:scripts) { described_class.new(redis: redis, keys: keys, ttl: ttl) }

  def create_execution
    # rubocop:disable Rails/SaveBang -- `ExecutionScripts#create` is a service API, not an ActiveRecord persistence method.
    scripts.create(
      execution_id: execution_id,
      project_id: project_id,
      workflow: workflow,
      stages: stages,
      batch_size: batch_size,
      metadata: metadata
    )
    # rubocop:enable Rails/SaveBang
  end

  def transition_to(status)
    scripts.transition(execution_id: execution_id, status: status)
  end

  def concurrently(*values)
    ready = Queue.new
    start = Queue.new

    threads = values.map do |value|
      Thread.new do
        ready << true
        start.pop

        yield(value)
      end
    end

    values.size.times { ready.pop }
    values.size.times { start << true }

    threads.map(&:value)
  end

  describe '#create' do
    it 'creates execution metadata', :aggregate_failures do
      expect(create_execution).to eq(execution_id)

      expect(redis_metadata).to include(
        'execution_id' => execution_id,
        'project_id' => project_id.to_s,
        'workflow' => workflow,
        'status' => 'created',
        'cancel_requested' => 'false',
        'batch_size' => batch_size.to_s,
        'processed_in_batch' => '0',
        'metadata' => metadata.to_json,
        'stages' => stages.to_json
      )

      expect(redis_metadata['created_at']).to be_present
    end

    it 'sets the current execution pointer' do
      create_execution

      expect(redis.with { |r| r.get(keys[:current]) }).to eq(execution_id)
    end

    it 'sets the latest execution pointer' do
      create_execution

      expect(redis.with { |r| r.get(keys[:latest]) }).to eq(execution_id)
    end

    it 'sets ttl on metadata, current and latest pointers' do
      create_execution

      expect(redis.with { |r| r.ttl(keys[:metadata]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
      expect(redis.with { |r| r.ttl(keys[:current]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
      expect(redis.with { |r| r.ttl(keys[:latest]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
    end

    it 'returns existing current execution without overwriting metadata', :aggregate_failures do
      redis.with { |r| r.set(keys[:current], existing_execution_id) }

      expect(create_execution).to eq(existing_execution_id)
      expect(redis_metadata).to be_empty
    end

    it 'does not overwrite latest when an active execution already exists', :aggregate_failures do
      redis.with do |r|
        r.set(keys[:current], existing_execution_id)
        r.set(keys[:latest], existing_execution_id)
      end

      expect(create_execution).to eq(existing_execution_id)
      expect(redis.with { |r| r.get(keys[:latest]) }).to eq(existing_execution_id)
      expect(redis_metadata).to be_empty
    end
  end

  describe '#start' do
    context 'when execution exists' do
      before do
        create_execution
      end

      it 'marks execution running', :aggregate_failures do
        expect(scripts.start(execution_id: execution_id)).to eq(:running)

        expect(redis_metadata['status']).to eq('running')
        expect(redis_metadata['started_at']).to be_present
        expect(redis_metadata['cancel_requested']).to eq('false')
      end

      it 'does not set ended_at' do
        scripts.start(execution_id: execution_id)

        expect(redis_metadata).not_to have_key('ended_at')
      end

      it 'removes previous ended_at value' do
        redis.with { |r| r.hset(keys[:metadata], 'ended_at', Time.current.iso8601) }

        scripts.start(execution_id: execution_id)

        expect(redis_metadata).not_to have_key('ended_at')
      end

      it 'refreshes latest pointer ttl' do
        redis.with { |r| r.expire(keys[:latest], 1) }

        scripts.start(execution_id: execution_id)

        expect(redis.with { |r| r.ttl(keys[:latest]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
      end

      it 'does not refresh latest pointer ttl when it points to another execution' do
        redis.with { |r| r.set(keys[:latest], existing_execution_id, ex: 1) }

        scripts.start(execution_id: execution_id)

        expect(redis.with { |r| r.ttl(keys[:latest]) }).to be <= 1
      end

      it 'returns already_running when already running' do
        scripts.start(execution_id: execution_id)

        expect(scripts.start(execution_id: execution_id)).to eq(:already_running)
      end

      context 'with terminal execution state' do
        where(:status, :expected) do
          'completed' | :completed
          'failed'    | :failed
          'cancelled' | :cancelled
        end

        with_them do
          before do
            redis.with { |r| r.hset(keys[:metadata], 'status', status) }
          end

          it 'returns current status without modifying execution', :aggregate_failures do
            expect(scripts.start(execution_id: execution_id)).to eq(expected)

            expect(redis_metadata['status']).to eq(status)
            expect(redis_metadata).not_to have_key('started_at')
          end
        end
      end
    end

    context 'when execution does not exist' do
      it 'returns not_found' do
        expect(scripts.start(execution_id: execution_id)).to eq(:not_found)
      end
    end
  end

  describe '#transition' do
    before do
      create_execution
      redis.with { |r| r.set(keys[:current], execution_id) }
    end

    where(:status, :expected) do
      :completed | :completed
      :failed    | :failed
      :cancelled | :cancelled
    end

    with_them do
      it 'transitions execution to the requested terminal state', :aggregate_failures do
        expect(transition_to(status)).to eq(expected)

        expect(redis_metadata['status']).to eq(status.to_s)
        expect(redis_metadata['ended_at']).to be_present
        expect(redis_metadata['processed_in_batch']).to eq('0')
      end
    end

    it 'sets cancel_requested when transitioning to cancelled' do
      transition_to(:cancelled)

      expect(redis_metadata['cancel_requested']).to eq('true')
    end

    it 'deletes current pointer when it points to the execution' do
      transition_to(:completed)

      expect(redis.with { |r| r.get(keys[:current]) }).to be_nil
    end

    it 'keeps latest pointer when execution completes', :aggregate_failures do
      transition_to(:completed)

      expect(redis.with { |r| r.get(keys[:current]) }).to be_nil
      expect(redis.with { |r| r.get(keys[:latest]) }).to eq(execution_id)
    end

    it 'refreshes metadata ttl after transition' do
      transition_to(:completed)

      expect(redis.with { |r| r.ttl(keys[:metadata]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
    end

    it 'refreshes latest pointer ttl after transition' do
      redis.with { |r| r.expire(keys[:latest], 1) }

      transition_to(:completed)

      expect(redis.with { |r| r.ttl(keys[:latest]) }).to be_between(ttl.to_i - 1, ttl.to_i).inclusive
    end

    it 'does not refresh latest pointer ttl when it points to another execution' do
      redis.with { |r| r.set(keys[:latest], existing_execution_id, ex: 1) }

      transition_to(:completed)

      expect(redis.with { |r| r.ttl(keys[:latest]) }).to be <= 1
    end

    it 'does not delete current pointer when it points to another execution' do
      redis.with { |r| r.set(keys[:current], existing_execution_id) }

      transition_to(:completed)

      expect(redis.with { |r| r.get(keys[:current]) }).to eq(existing_execution_id)
    end

    context 'when execution does not exist' do
      it 'returns not_found' do
        redis.with { |r| r.del(keys[:metadata]) }

        expect(transition_to(:cancelled)).to eq(:not_found)
      end
    end

    context 'with terminal execution state' do
      where(:status, :expected) do
        'completed' | :completed
        'failed'    | :failed
        'cancelled' | :cancelled
      end

      with_them do
        before do
          redis.with { |r| r.hset(keys[:metadata], 'status', status) }
        end

        it 'returns current status without modifying execution', :aggregate_failures do
          expect(transition_to(:cancelled)).to eq(expected)

          expect(redis_metadata['status']).to eq(status)
          expect(redis_metadata['cancel_requested']).to eq('false')
          expect(redis_metadata).not_to have_key('ended_at')
        end
      end
    end
  end

  describe 'retry safety' do
    before do
      create_execution
      scripts.start(execution_id: execution_id)
    end

    it 'preserves the first successful transition when retries race' do
      results = concurrently(:completed, :failed, :completed) { |status| transition_to(status) }
      winner = redis_metadata['status']

      expect(winner).to be_in(%w[completed failed])
      expect(results.uniq).to eq([winner.to_sym])
    end
  end

  describe 'concurrency safety' do
    it 'creates exactly one execution under concurrent creation' do
      ids = concurrently(nil, nil, nil) do
        # rubocop:disable Rails/SaveBang -- `ExecutionScripts#create` is a service API, not an ActiveRecord persistence method.
        scripts.create(
          execution_id: SecureRandom.uuid,
          project_id: project_id,
          workflow: workflow,
          stages: stages,
          batch_size: batch_size,
          metadata: metadata
        )
        # rubocop:enable Rails/SaveBang
      end

      expect(ids.uniq.size).to eq(1)
    end

    it 'allows only one terminal transition under races' do
      create_execution
      scripts.start(execution_id: execution_id)

      results = concurrently(:completed, :failed, :cancelled) { |status| transition_to(status) }
      winner = redis_metadata['status']

      expect(winner).to be_in(%w[completed failed cancelled])
      expect(results.uniq).to eq([winner.to_sym])
      expect(redis_metadata['ended_at']).to be_present
    end
  end

  describe 'global invariants' do
    before do
      create_execution
      scripts.start(execution_id: execution_id)
    end

    it 'keeps the first terminal state' do
      expect(transition_to(:completed)).to eq(:completed)
      expect(transition_to(:failed)).to eq(:completed)
      expect(transition_to(:cancelled)).to eq(:completed)

      expect(redis_metadata['status']).to eq('completed')
    end

    it 'returns not_found when metadata is removed externally' do
      redis.with { |r| r.del(keys[:metadata]) }

      expect(transition_to(:completed)).to eq(:not_found)
    end
  end
end
