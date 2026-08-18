# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Tasks::Gitlab::Nav::VariantGenerator, feature_category: :navigation do
  let(:generator) { described_class.new(dumper: nil) }

  def menus(tags)
    tags.map { |t| { tags: t } }
  end

  describe '#compare_variants' do
    it "outputs 'ff' when an entry only appears when feature flagged" do
      tags = generator.compare_variants(menus([%w[sm ff], %w[dotcom ff]]))
      expect(tags).to eq(['ff'])
    end

    it "outputs 'sm' when an entry only appears in self-managed" do
      tags = generator.compare_variants(menus([%w[sm], %w[sm ff]]))
      expect(tags).to eq(['sm'])
    end

    it "outputs 'sm' and 'ff' when an entry only appears in SM while feature flagged" do
      tags = generator.compare_variants(menus([%w[sm ff]]))
      expect(tags).to eq(%w[ff sm])
    end

    it "outputs 'dotcom' when an entry only appears in SaaS" do
      tags = generator.compare_variants(menus([%w[dotcom], %w[dotcom ff]]))
      expect(tags).to eq(['dotcom'])
    end

    it "outputs 'dotcom' and 'ff' when an entry only appears in SaaS while feature flagged" do
      tags = generator.compare_variants(menus([%w[dotcom ff]]))
      expect(tags).to eq(%w[ff dotcom])
    end

    it "outputs nothing if an entry appears in all environments" do
      tags = generator.compare_variants(menus([%w[sm], %w[sm ff], %w[dotcom], %w[dotcom ff]]))
      expect(tags).to eq([])
    end
  end
end
