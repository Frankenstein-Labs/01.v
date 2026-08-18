# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Authz::Role, feature_category: :permissions do
  describe '.get_from_access_level' do
    Gitlab::Access.options_with_minimal_access.each do |label, access_level|
      it "resolves '#{label}' (#{access_level}) to a Role" do
        expect(described_class.get_from_access_level(access_level)).to be_a(described_class)
      end
    end
  end
end
