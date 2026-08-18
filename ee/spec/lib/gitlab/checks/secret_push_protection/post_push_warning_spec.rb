# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::PostPushWarning, :clean_gitlab_redis_shared_state, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }

  let_it_be(:repository) { project.repository }
  let(:protocol) { 'http' }
  let(:git_user) { user }

  subject(:post_push_warning) { described_class.new(repository, git_user, protocol) }

  describe '.fetch_message' do
    let(:key) { "secret_push_protection:warning:#{user.id}:#{project.id}" }

    context 'with a warning message queue' do
      before do
        post_push_warning.add_message
      end

      it 'returns the warning message' do
        expect(described_class.fetch_message(user, project.repository)).to eq(post_push_warning.message)
      end

      it 'deletes the warning message from redis' do
        expect(Gitlab::Redis::SharedState.with { |redis| redis.get(key) }).not_to be_nil

        described_class.fetch_message(user, project.repository)

        expect(Gitlab::Redis::SharedState.with { |redis| redis.get(key) }).to be_nil
      end
    end
  end

  describe '#add_message' do
    it 'queues a warning message' do
      expect(post_push_warning.add_message).to eq('OK')
    end

    context 'when user is nil' do
      let(:git_user) { nil }

      it 'does not queue a message' do
        expect(post_push_warning.add_message).to be_nil
      end
    end
  end

  describe '#message' do
    it 'returns the warning message' do
      expect(post_push_warning.message).to eq(
        'Secret push protection encountered an internal error and could not ' \
          'scan this push. The push has been accepted.'
      )
    end
  end

  context 'when changed_paths_count and changed_paths_threshold are set' do
    subject(:post_push_warning) { described_class.new(repository, git_user, protocol, 8000, 1000) }

    describe '#message' do
      it 'returns the warning message' do
        expect(post_push_warning.message).to eq(
          'Secret push protection was skipped: 8000 changed files exceeds ' \
            'the threshold of 1000. The push has been accepted.'
        )
      end
    end
  end
end
