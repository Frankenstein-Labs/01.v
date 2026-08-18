# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TriggerableHooks, feature_category: :webhooks do
  before do
    stub_const('TestableHook', Class.new(WebHook))

    TestableHook.class_eval do
      include TriggerableHooks
      triggerable_hooks [:vulnerability_hooks, :member_approval_hooks]

      self.allow_legacy_sti_class = true

      scope :executable, -> { all }
    end
  end

  describe 'scopes' do
    it 'defines a scope for each of the requested triggers' do
      expect(TestableHook).to respond_to :vulnerability_hooks
      expect(TestableHook).to respond_to :member_approval_hooks
    end
  end

  describe '.hooks_for' do
    let_it_be(:project) { create(:project) }

    context 'when the model has the required trigger scope' do
      it 'returns the record' do
        hook = TestableHook.create!(url: 'http://example.com', project_id: project.id, member_approval_events: true)

        expect(TestableHook.hooks_for(:member_approval_hooks)).to eq [hook]
      end
    end
  end
end
