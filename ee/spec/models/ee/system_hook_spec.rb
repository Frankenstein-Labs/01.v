# frozen_string_literal: true

require "spec_helper"

RSpec.describe SystemHook, feature_category: :webhooks do
  describe '.available_hooks' do
    it 'includes EE-specific hooks' do
      expect(described_class.available_hooks).to include(:member_approval_hooks)
    end
  end

  describe '.default attributes' do
    let(:system_hook) { described_class.new }

    it 'sets defined default parameters' do
      attrs = {
        member_approval_events: false
      }
      expect(system_hook).to have_attributes(attrs)
    end
  end
end
