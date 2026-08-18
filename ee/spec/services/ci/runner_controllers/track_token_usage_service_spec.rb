# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::TrackTokenUsageService, feature_category: :continuous_integration do
  let_it_be(:runner_controller) { create(:ci_runner_controller) }

  describe '#execute', :clean_gitlab_redis_cache do
    let(:token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }

    subject(:execute) { described_class.new(token).execute }

    shared_examples 'updates Redis cache' do
      it 'writes last_used_at to Redis' do
        execute

        Gitlab::Redis::Cache.with do |redis|
          redis_key = "cache:#{token.class}:#{token.id}:attributes"
          expect(redis.get(redis_key)).to be_present
        end
      end
    end

    context 'when last_used_at was updated recently' do
      let(:token) { create(:ci_runner_controller_token, :recently_used, runner_controller: runner_controller) }

      it 'does not update the database' do
        expect { execute }.not_to change { token.reload.read_attribute(:last_used_at) }
      end

      include_examples 'updates Redis cache'
    end

    context 'when last_used_at was not updated recently' do
      it 'updates the database' do
        expect { execute }.to change { token.reload.read_attribute(:last_used_at) }
      end

      it 'returns a success response' do
        expect(execute).to be_success
      end

      include_examples 'updates Redis cache'

      context 'with invalid token' do
        before do
          token.description = SecureRandom.hex(2000)
        end

        it 'still updates the database' do
          expect(token).to be_invalid

          expect { execute }.to change { token.reload.read_attribute(:last_used_at) }
        end

        include_examples 'updates Redis cache'
      end
    end

    context 'when last_used_at is nil', :freeze_time do
      it 'updates the database' do
        expect(token.read_attribute(:last_used_at)).to be_nil

        expect { execute }.to change { token.reload.read_attribute(:last_used_at) }.from(nil).to(Time.current.utc)
      end

      include_examples 'updates Redis cache'
    end

    context 'when usage tracking raises an error' do
      before do
        allow(token).to receive(:update_columns).and_raise(ActiveRecord::NotNullViolation, 'error message')
      end

      it 'tracks the exception without raising' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(
            instance_of(ActiveRecord::NotNullViolation),
            runner_controller_id: runner_controller.id
          )

        execute
      end

      it 'returns an error response' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(execute).to be_error
      end
    end
  end
end
