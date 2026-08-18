# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let(:user) { build_stubbed(:user) }

  describe '.user_onboarding_in_progress?' do
    where(:user_present, :onboarding_enabled, :onboarding_in_progress, :use_cache, :cached_value, :expected_result) do
      # user nil cases
      false | true  | true  | false | nil   | false
      false | true  | true  | true  | true  | false

      # onboarding disabled cases
      true  | false | true  | false | nil   | false
      true  | false | true  | true  | true  | false

      # use_cache: false cases
      true  | true  | true  | false | nil   | true
      true  | true  | false | false | true  | false

      # use_cache: true, user.onboarding_in_progress? false cases
      true  | true  | false | true  | true  | false

      # use_cache: true, user.onboarding_in_progress? true, cached cases
      true  | true  | true  | true  | true  | true
      true  | true  | true  | true  | false | false

      # use_cache: true, user.onboarding_in_progress? true, no cache cases
      true  | true  | true  | true  | nil   | true
    end

    with_them do
      before do
        stub_saas_features(onboarding: onboarding_enabled)

        if user_present
          user.onboarding_in_progress = onboarding_in_progress
          allow(described_class).to receive(:fetch_onboarding_in_progress).with(user).and_return(cached_value)
        end
      end

      it 'returns the expected result' do
        actual_user = user_present ? user : nil
        expect(described_class.user_onboarding_in_progress?(actual_user, use_cache: use_cache)).to eq(expected_result)
      end
    end

    it 'does not check cache when use_cache is false' do
      stub_saas_features(onboarding: true)
      user.onboarding_in_progress = true

      expect(described_class).not_to receive(:fetch_onboarding_in_progress)

      described_class.user_onboarding_in_progress?(user, use_cache: false)
    end

    it 'does not check cache when user.onboarding_in_progress? is false' do
      stub_saas_features(onboarding: true)
      user.onboarding_in_progress = false

      expect(described_class).not_to receive(:fetch_onboarding_in_progress)

      described_class.user_onboarding_in_progress?(user, use_cache: true)
    end
  end

  describe '.fetch_onboarding_in_progress', :use_clean_rails_memory_store_caching do
    let(:cache_key) { "user_onboarding_in_progress:#{user.id}" }

    it 'fetches from Rails cache with the correct key' do
      Rails.cache.write(cache_key, true)

      expect(described_class.fetch_onboarding_in_progress(user)).to be(true)
    end

    it 'returns nil when cache is empty' do
      expect(described_class.fetch_onboarding_in_progress(user)).to be_nil
    end
  end

  describe '.cache_onboarding_in_progress', :use_clean_rails_memory_store_caching do
    let(:cache_key) { "user_onboarding_in_progress:#{user.id}" }

    it 'caches true when onboarding_in_progress is true' do
      user.onboarding_in_progress = true

      described_class.cache_onboarding_in_progress(user)

      expect(Rails.cache.fetch(cache_key)).to be(true)
    end

    it 'caches false when onboarding_in_progress is false' do
      user.onboarding_in_progress = false

      described_class.cache_onboarding_in_progress(user)

      expect(Rails.cache.fetch(cache_key)).to be(false)
    end
  end

  describe '.completed_welcome_step?' do
    let(:user) { build(:user) }

    context 'with a user who has never set the value' do
      it 'returns false' do
        expect(described_class.completed_welcome_step?(user)).to be false
      end
    end

    context 'when value has been explicitly set' do
      where(:value_to_set, :expected_result) do
        true  | true
        false | true
      end

      with_them do
        before do
          user.onboarding_status_setup_for_company = value_to_set
        end

        it 'returns true indicating step was completed' do
          expect(described_class.completed_welcome_step?(user)).to be true
        end
      end
    end
  end

  describe '.migrating_to_unified_welcome?' do
    let(:user) { build(:user, onboarding_status_step_url: step_url) }

    subject { described_class.migrating_to_unified_welcome?(user) }

    where(:step_url, :expected_result) do
      '/users/sign_up/welcome?migrating=true'           | true
      '/users/sign_up/welcome?migrating=true&foo=bar'   | true
      '/users/sign_up/welcome?migrating=false'          | false
      '/users/sign_up/welcome'                          | false
      '/users/sign_up/company'                          | false
      ''                                                | false
      nil                                               | false
    end

    with_them do
      it { is_expected.to be(expected_result) }
    end

    context 'when the step_url is not a parseable URI' do
      let(:step_url) { 'http://[invalid' }

      it { is_expected.to be(false) }
    end
  end

  describe '.enabled?' do
    subject { described_class.enabled? }

    context 'when onboarding feature is available' do
      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when onboarding feature is not available' do
      it { is_expected.to be(false) }
    end
  end

  describe '.add_on_seat_assignment_iterable_params' do
    let(:namespace) { build(:namespace, id: non_existing_record_id) }

    subject(:params) { described_class.add_on_seat_assignment_iterable_params(user, 'product_interaction', namespace) }

    it 'has the correct params that are stringified' do
      expected_params = {
        'first_name' => user.first_name,
        'last_name' => user.last_name,
        'work_email' => user.email,
        'namespace_id' => namespace.id,
        'product_interaction' => 'product_interaction',
        'existing_plan' => namespace.actual_plan_name,
        'preferred_language' => 'English',
        'opt_in' => user.onboarding_status_email_opt_in
      }

      expect(params).to eq(expected_params)
    end
  end

  describe '.uat_test_account?' do
    subject { described_class.uat_test_account?(user) }

    context 'when user has a UAT test account email' do
      let(:user) { build(:user, email: 'user+uat@gitlab.com') }

      it { is_expected.to be true }
    end

    context 'when user has a normal gitlab.com email' do
      let(:user) { build(:user, email: 'employee@gitlab.com') }

      it { is_expected.to be false }
    end

    context 'when user has a plus-addressed email on another domain' do
      let(:user) { build(:user, email: 'user+test@gmail.com') }

      it { is_expected.to be false }
    end
  end
end
