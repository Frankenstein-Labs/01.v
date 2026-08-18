# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfilePolicy, feature_category: :security_testing_configuration do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

  subject { described_class.new(user, scan_profile) }

  describe 'read_security_scan_profiles' do
    let(:policy) { :read_security_scan_profiles }

    context 'when security_scan_profiles is not available' do
      before do
        stub_licensed_features(security_scan_profiles: false)
      end

      before_all do
        group.add_owner(user)
      end

      it { is_expected.to be_disallowed(policy) }
    end

    context 'when security_scan_profiles is available' do
      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when the current user has developer access to the group' do
        before_all do
          group.add_developer(user)
        end

        it { is_expected.to be_allowed(policy) }
      end

      context 'when the current user has reporter access to the group' do
        before_all do
          group.add_reporter(user)
        end

        it { is_expected.to be_disallowed(policy) }
      end

      context 'when the current user has guest access to the group' do
        before_all do
          group.add_guest(user)
        end

        it { is_expected.to be_disallowed(policy) }
      end

      context 'when the current user does not have access to the group' do
        it { is_expected.to be_disallowed(policy) }
      end
    end
  end

  describe 'update_security_scan_profiles' do
    let(:policy) { :update_security_scan_profiles }

    context 'when security_scan_profiles is not available' do
      before do
        stub_licensed_features(security_scan_profiles: false)
      end

      before_all do
        group.add_owner(user)
      end

      it { is_expected.to be_disallowed(policy) }
    end

    context 'when security_scan_profiles is available' do
      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when the current user has maintainer access to the group' do
        before_all do
          group.add_maintainer(user)
        end

        it { is_expected.to be_allowed(policy) }
      end

      context 'when the current user has developer access to the group' do
        before_all do
          group.add_developer(user)
        end

        it { is_expected.to be_disallowed(policy) }
      end

      context 'when the current user does not have access to the group' do
        it { is_expected.to be_disallowed(policy) }
      end
    end
  end
end
