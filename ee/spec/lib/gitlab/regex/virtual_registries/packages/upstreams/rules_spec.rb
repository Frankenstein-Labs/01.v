# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Regex::VirtualRegistries::Packages::Upstreams::Rules, feature_category: :virtual_registry do
  describe '.maven_app_group_wildcard_pattern_regex' do
    subject { described_class.maven_app_group_wildcard_pattern_regex }

    it { is_expected.to match('*') }
    it { is_expected.to match('com.example') }
    it { is_expected.to match('com.example.*') }
    it { is_expected.to match('*.example.com') }
    it { is_expected.to match('*.example.*') }
    it { is_expected.to match('org.apache.commons') }

    it { is_expected.not_to match('') }
    it { is_expected.not_to match('com.example.**') }
    it { is_expected.not_to match('**.example.com') }
    it { is_expected.not_to match('*com/example') }
    it { is_expected.not_to match('/com.example*') }
    it { is_expected.not_to match('*com.example/') }
    it { is_expected.not_to match('*com/example*') }
  end

  describe '.maven_app_name_wildcard_pattern_regex' do
    subject { described_class.maven_app_name_wildcard_pattern_regex }

    it { is_expected.to match('*') }
    it { is_expected.to match('my-app') }
    it { is_expected.to match('artifact-*') }
    it { is_expected.to match('*-artifact') }
    it { is_expected.to match('*-artifact-*') }
    it { is_expected.to match('my_app') }
    it { is_expected.to match('MyApp') }

    it { is_expected.not_to match('') }
    it { is_expected.not_to match('artifact-**') }
    it { is_expected.not_to match('**-artifact') }
    it { is_expected.not_to match('my/app') }
    it { is_expected.not_to match('*my/app') }
    it { is_expected.not_to match('my/app*') }
    it { is_expected.not_to match('*my/app*') }
  end

  describe '.maven_version_wildcard_pattern_regex' do
    subject { described_class.maven_version_wildcard_pattern_regex }

    it { is_expected.to match('*') }
    it { is_expected.to match('1.0.0') }
    it { is_expected.to match('1.0.*') }
    it { is_expected.to match('1.*.*') }
    it { is_expected.to match('*-SNAPSHOT') }
    it { is_expected.to match('*-SNAPSHOT-*') }
    it { is_expected.to match('2.1.0-beta') }
    it { is_expected.to match('1.0.0-SNAPSHOT') }

    it { is_expected.not_to match('') }
    it { is_expected.not_to match('1.0.**') }
    it { is_expected.not_to match('**-SNAPSHOT') }
    it { is_expected.not_to match('*1..0') }
    it { is_expected.not_to match('*1/0/0') }
    it { is_expected.not_to match('*1:0:0') }
  end
end
