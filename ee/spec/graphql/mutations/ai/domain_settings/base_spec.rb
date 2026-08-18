# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::DomainSettings::Base, feature_category: :duo_agent_platform do
  describe 'VALID_DOMAIN_REGEX' do
    subject { described_class::VALID_DOMAIN_REGEX }

    it { is_expected.to match('www.google.com') }
    it { is_expected.to match('*.google.com') }
    it { is_expected.to match('*.gitlab.stuff.com') }
    it { is_expected.to match('example.com') }

    it { is_expected.not_to match('localhost') }
    it { is_expected.not_to match('bad domain') }
    it { is_expected.not_to match('also bad!') }
    it { is_expected.not_to match('-bad.com') }
    it { is_expected.not_to match('bad-.com') }
    it { is_expected.not_to match('*.*.com') }
    it { is_expected.not_to match('') }
    it { is_expected.not_to match("example.com\nfoo") }
  end
end
