# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Entitlement, feature_category: :secrets_management do
  describe 'constants' do
    it 'freezes STATES' do
      expect(described_class::STATES).to be_frozen
    end

    it 'exposes the documented states' do
      expect(described_class::STATES).to contain_exactly(
        :trial_eligible, :trial, :paid, :offline_paid, :blocked, :ineligible
      )
    end

    it 'freezes BLOCKED_REASONS' do
      expect(described_class::BLOCKED_REASONS).to be_frozen
    end

    it 'exposes the documented blocked reasons' do
      expect(described_class::BLOCKED_REASONS).to contain_exactly(
        :trial_expired, :credits_exhausted, :on_demand_disabled, :grace, :subscription_grace_period_expired
      )
    end
  end

  describe '#permits_writes?' do
    %i[trial paid offline_paid].each do |state|
      it "is true for #{state}" do
        expect(described_class.new(state: state).permits_writes?).to be true
      end
    end

    %i[trial_eligible ineligible].each do |state|
      it "is false for #{state}" do
        expect(described_class.new(state: state).permits_writes?).to be false
      end
    end

    it 'is false for blocked' do
      entitlement = described_class.new(state: :blocked, blocked_reason: :trial_expired)

      expect(entitlement.permits_writes?).to be false
    end
  end

  describe '#permits_access?' do
    %i[trial_eligible trial paid offline_paid].each do |state|
      it "is true for #{state}" do
        expect(described_class.new(state: state).permits_access?).to be true
      end
    end

    it 'is false for ineligible' do
      expect(described_class.new(state: :ineligible).permits_access?).to be false
    end

    it 'is false for blocked' do
      entitlement = described_class.new(state: :blocked, blocked_reason: :trial_expired)

      expect(entitlement.permits_access?).to be false
    end
  end

  describe '#write_action_denial_reason' do
    %i[trial paid offline_paid].each do |state|
      it "is nil for #{state}" do
        expect(described_class.new(state: state).write_action_denial_reason).to be_nil
      end
    end

    it 'is :ineligible for ineligible' do
      entitlement = described_class.new(state: :ineligible)
      expect(entitlement.write_action_denial_reason).to eq(:ineligible)
    end

    it 'is :trial_required for trial_eligible' do
      entitlement = described_class.new(state: :trial_eligible)
      expect(entitlement.write_action_denial_reason).to eq(:trial_required)
    end

    described_class::BLOCKED_REASONS.each do |reason|
      it "is the blocked_reason (#{reason}) for blocked" do
        entitlement = described_class.new(state: :blocked, blocked_reason: reason)
        expect(entitlement.write_action_denial_reason).to eq(reason)
      end
    end
  end

  describe '#permits_read?' do
    %i[trial_eligible trial paid offline_paid].each do |state|
      it "is true for #{state}" do
        expect(described_class.new(state: state).permits_read?).to be true
      end
    end

    described_class::BLOCKED_REASONS.each do |reason|
      it "is true for blocked/#{reason}" do
        entitlement = described_class.new(state: :blocked, blocked_reason: reason)
        expect(entitlement.permits_read?).to be true
      end
    end

    it 'is false for ineligible' do
      expect(described_class.new(state: :ineligible).permits_read?).to be false
    end
  end

  describe '#permits_direct_read?' do
    %i[trial_eligible trial paid offline_paid].each do |state|
      it "is true for #{state}" do
        expect(described_class.new(state: state).permits_direct_read?).to be true
      end
    end

    it 'is true for blocked/grace (the read-only carve-out)' do
      entitlement = described_class.new(state: :blocked, blocked_reason: :grace)
      expect(entitlement.permits_direct_read?).to be true
    end

    %i[trial_expired credits_exhausted on_demand_disabled subscription_grace_period_expired].each do |reason|
      it "is false for blocked/#{reason}" do
        entitlement = described_class.new(state: :blocked, blocked_reason: reason)
        expect(entitlement.permits_direct_read?).to be false
      end
    end

    it 'is false for ineligible' do
      expect(described_class.new(state: :ineligible).permits_direct_read?).to be false
    end

    context 'when the beta program has ended' do
      it 'is false for trial_eligible' do
        entitlement = described_class.new(state: :trial_eligible, beta_program_ended: true)

        expect(entitlement.permits_direct_read?).to be false
      end

      it 'is true for trial_eligible when beta_program_ended is explicitly false' do
        entitlement = described_class.new(state: :trial_eligible, beta_program_ended: false)

        expect(entitlement.permits_direct_read?).to be true
      end

      it 'leaves permits_read? unaffected for trial_eligible (Rails-brokered reads stay)' do
        entitlement = described_class.new(state: :trial_eligible, beta_program_ended: true)

        expect(entitlement.permits_read?).to be true
      end

      it 'does not affect states other than trial_eligible' do
        entitlement = described_class.new(state: :trial, beta_program_ended: true)

        expect(entitlement.permits_direct_read?).to be true
      end
    end
  end

  describe '#in_grace?' do
    it 'is true when blocked with :grace' do
      entitlement = described_class.new(state: :blocked, blocked_reason: :grace)
      expect(entitlement.in_grace?).to be true
    end

    it 'is false when blocked with a non-grace reason' do
      entitlement = described_class.new(state: :blocked, blocked_reason: :subscription_grace_period_expired)
      expect(entitlement.in_grace?).to be false
    end

    it 'is false for non-blocked states even with blocked_reason set' do
      entitlement = described_class.new(state: :trial, blocked_reason: :grace)
      expect(entitlement.in_grace?).to be false
    end
  end

  describe 'construction' do
    it 'requires only state; defaults every other field to nil' do
      entitlement = described_class.new(state: :ineligible)

      expect(entitlement).to have_attributes(
        state: :ineligible,
        blocked_reason: nil,
        trial_started_at: nil,
        trial_expires_at: nil,
        credits_remaining: nil,
        credits_total: nil,
        on_demand_enabled: nil,
        beta_program_ended: nil
      )
    end

    it 'carries credits_total alongside credits_remaining (SSOT for FE % remaining)', :aggregate_failures do
      entitlement = described_class.new(
        state: :trial,
        credits_remaining: 320,
        credits_total: 500
      )

      expect(entitlement.credits_remaining).to eq(320)
      expect(entitlement.credits_total).to eq(500)
    end

    it 'is frozen' do
      expect(described_class.new(state: :ineligible)).to be_frozen
    end

    it 'raises NoMethodError on unknown attributes' do
      expect { described_class.new(state: :ineligible).staet }.to raise_error(NoMethodError)
    end

    it 'raises ArgumentError for a state not in STATES' do
      expect { described_class.new(state: :bogus) }
        .to raise_error(ArgumentError, /Unknown state: :bogus/)
    end

    it 'raises ArgumentError for a blocked_reason not in BLOCKED_REASONS' do
      expect { described_class.new(state: :blocked, blocked_reason: :bogus) }
        .to raise_error(ArgumentError, /Unknown blocked_reason: :bogus/)
    end

    it 'raises ArgumentError when state is :blocked and blocked_reason is nil' do
      expect { described_class.new(state: :blocked) }
        .to raise_error(ArgumentError, /blocked_reason is required when state is :blocked/)
    end

    it 'accepts nil blocked_reason without raising' do
      expect { described_class.new(state: :paid, blocked_reason: nil) }.not_to raise_error
    end
  end

  describe '.for' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, group: root_group) }

    before do
      stub_saas_features(gitlab_com_subscriptions: false)
    end

    it 'accepts nil (instance)' do
      expect { described_class.for(nil) }.not_to raise_error
    end

    it 'accepts a top-level Group' do
      expect { described_class.for(root_group) }.not_to raise_error
    end

    it 'accepts an optional user: kwarg (default nil) and forwards it to Resolver' do
      user = build_stubbed(:user)

      expect(described_class::Resolver).to receive(:new).with(root_group, user: user).and_call_original

      described_class.for(root_group, user: user)
    end

    it 'raises ArgumentError for a subgroup' do
      expect { described_class.for(subgroup) }
        .to raise_error(ArgumentError, /top-level Group or nil/)
    end

    it 'raises ArgumentError for a project' do
      expect { described_class.for(project) }
        .to raise_error(ArgumentError, /top-level Group or nil/)
    end

    it 'returns an Entitlement value object' do
      expect(described_class.for(root_group)).to be_a(described_class)
    end

    it 'memoizes per request for repeated calls with the same namespace' do
      ::Gitlab::SafeRequestStore.ensure_request_store do
        expect(::GitlabSubscriptions::AddOnPurchase).to receive(:for_secrets_manager).once.and_call_original

        2.times { described_class.for(root_group) }
      end
    end

    it 'shares the memoized result across distinct namespaces on self-managed' do
      other_root_group = create(:group)

      ::Gitlab::SafeRequestStore.ensure_request_store do
        expect(::GitlabSubscriptions::AddOnPurchase).to receive(:for_secrets_manager).once.and_call_original

        described_class.for(nil)
        described_class.for(root_group)
        described_class.for(other_root_group)
      end
    end

    it 'does not share memoization across distinct request stores' do
      expect(::GitlabSubscriptions::AddOnPurchase).to receive(:for_secrets_manager).twice.and_call_original

      ::Gitlab::SafeRequestStore.ensure_request_store { described_class.for(root_group) }
      ::Gitlab::SafeRequestStore.ensure_request_store { described_class.for(root_group) }
    end
  end

  describe '.root_namespace_for' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project) { create(:project, group: root_group) }

    it 'returns nil for nil' do
      expect(described_class.root_namespace_for(nil)).to be_nil
    end

    it 'returns the group itself for a top-level group' do
      expect(described_class.root_namespace_for(root_group)).to eq(root_group)
    end

    it "returns the project's root ancestor group" do
      expect(described_class.root_namespace_for(project)).to eq(root_group)
    end

    it "returns the subgroup's root ancestor group" do
      expect(described_class.root_namespace_for(subgroup)).to eq(root_group)
    end

    it 'returns nil for a project in a personal namespace' do
      personal_project = create(:project, :in_user_namespace)

      expect(described_class.root_namespace_for(personal_project)).to be_nil
    end
  end
end
