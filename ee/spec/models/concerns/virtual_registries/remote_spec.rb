# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Remote, feature_category: :virtual_registry do
  let(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }

  describe '#remote?' do
    it { expect(upstream.remote?).to be(true) }
  end

  describe '#local?' do
    it { expect(upstream.local?).to be(false) }
  end

  describe '#upstream_type' do
    it { expect(upstream.upstream_type).to eq('remote') }
  end
end
