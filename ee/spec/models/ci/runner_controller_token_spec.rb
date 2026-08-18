# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllerToken, feature_category: :continuous_integration do
  let_it_be(:runner_controller) { create(:ci_runner_controller) }

  describe 'constants' do
    describe 'INACTIVE_AFTER' do
      subject { described_class::INACTIVE_AFTER }

      it { is_expected.to eq(1.hour) }
      it { is_expected.to be_frozen }
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:runner_controller).class_name('Ci::RunnerController') }
  end

  describe 'validations' do
    subject(:token) { create(:ci_runner_controller_token) }

    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
  end

  describe 'token' do
    it 'uses TokenAuthenticatable' do
      expect(described_class.token_authenticatable_fields).to include(:token)
    end

    it 'has the correct token prefix' do
      token = create(:ci_runner_controller_token, runner_controller: runner_controller)

      expect(token.token).to start_with('glrct-')
    end
  end

  describe 'callbacks' do
    it 'calls ensure_token before create' do
      token = build(:ci_runner_controller_token, runner_controller: runner_controller)

      expect(token).to receive(:ensure_token).and_call_original
      token.save!
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, revoked: 1) }
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns only active tokens' do
        active_token = create(:ci_runner_controller_token, status: :active)
        revoked_token = create(:ci_runner_controller_token, status: :revoked)

        expect(described_class.active).to include(active_token)
        expect(described_class.active).not_to include(revoked_token)
      end
    end

    describe '.connected' do
      subject(:connected) { described_class.connected }

      let!(:recently_used) do
        create(:ci_runner_controller_token, :recently_used)
      end

      let!(:stale_token) do
        create(:ci_runner_controller_token, :not_recently_used)
      end

      let!(:never_used) do
        create(:ci_runner_controller_token, :unused)
      end

      let!(:revoked_recent) do
        create(:ci_runner_controller_token, :revoked, :recently_used)
      end

      it 'returns only active tokens used within INACTIVE_AFTER' do
        is_expected.to contain_exactly(recently_used)
      end
    end
  end

  describe 'cached attributes', :clean_gitlab_redis_cache do
    subject(:token) { create(:ci_runner_controller_token) }

    describe 'last_used_at' do
      subject(:last_used_at) { token.last_used_at }

      it 'reads last_used_at from cache when available' do
        cached_time = Time.current.utc
        token.cache_attributes(last_used_at: cached_time)

        is_expected.to be_within(1.second).of(cached_time)
      end

      it 'falls back to database when cache is empty' do
        db_time = 2.days.ago
        token.update_columns(last_used_at: db_time)

        is_expected.to be_within(1.second).of(db_time)
      end
    end
  end

  describe '#revoke' do
    it 'sets the status to revoked' do
      token = create(:ci_runner_controller_token, status: :active)
      token.revoke!

      expect(token.status).to eq('revoked')
    end
  end
end
