# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ExternalAgents::AgentIdentity, feature_category: :software_composition_analysis do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:identity) do
    create(:ai_agent_identity, user: user, project: project,
      agent_type: 'claude-code', machine_fingerprint: 'a' * 64)
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:agent_type) }
    it { is_expected.to validate_presence_of(:machine_fingerprint) }

    it 'validates agent_type is in the allowlist' do
      identity = build(:ai_agent_identity, agent_type: 'unknown-agent')
      expect(identity).not_to be_valid
      expect(identity.errors[:agent_type]).to be_present
    end

    it 'accepts valid agent types' do
      described_class::AGENT_TYPES.each do |agent_type|
        identity = build(:ai_agent_identity, agent_type: agent_type)
        expect(identity).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'scopes' do
    let_it_be(:revoked_identity) do
      create(:ai_agent_identity, user: user, project: project,
        agent_type: 'opencode', machine_fingerprint: 'b' * 64,
        revoked_at: Time.current)
    end

    describe '.active' do
      it 'returns only non-revoked identities' do
        expect(described_class.active).to include(identity)
        expect(described_class.active).not_to include(revoked_identity)
      end
    end

    describe '.revoked' do
      it 'returns only revoked identities' do
        expect(described_class.revoked).to include(revoked_identity)
        expect(described_class.revoked).not_to include(identity)
      end
    end

    describe '.for_project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_identity) do
        create(:ai_agent_identity, user: user, project: other_project)
      end

      it 'returns only identities for the given project' do
        expect(described_class.for_project(project)).to include(identity)
        expect(described_class.for_project(project)).not_to include(other_identity)
      end
    end

    describe '.for_user' do
      let_it_be(:other_user) { create(:user) }
      let_it_be(:other_identity) do
        create(:ai_agent_identity, user: other_user, project: project,
          machine_fingerprint: 'c' * 64)
      end

      it 'returns only identities for the given user' do
        expect(described_class.for_user(user)).to include(identity)
        expect(described_class.for_user(user)).not_to include(other_identity)
      end
    end
  end

  describe '#revoked?' do
    it 'returns false when revoked_at is nil' do
      expect(identity.revoked?).to be false
    end

    it 'returns true when revoked_at is set' do
      identity = build(:ai_agent_identity, revoked_at: Time.current)
      expect(identity.revoked?).to be true
    end
  end

  describe '#revoke!' do
    let_it_be(:revokable_identity) do
      create(:ai_agent_identity, user: user, project: project,
        agent_type: 'opencode', machine_fingerprint: 'd' * 64)
    end

    it 'sets revoked_at' do
      expect { revokable_identity.revoke! }
        .to change { revokable_identity.reload.revoked_at }.from(nil)
    end

    it 'marks the identity as revoked' do
      revokable_identity.revoke!
      expect(revokable_identity.revoked?).to be true
    end
  end

  describe '.register' do
    let(:fingerprint) { 'e' * 64 }

    it 'creates a new identity' do
      expect do
        described_class.register(
          user: user,
          project: project,
          agent_type: 'claude-code',
          machine_fingerprint: fingerprint
        )
      end.to change { described_class.count }.by(1)
    end

    it 'returns an existing identity on repeat call' do
      first = described_class.register(
        user: user, project: project,
        agent_type: 'claude-code', machine_fingerprint: fingerprint
      )
      second = described_class.register(
        user: user, project: project,
        agent_type: 'claude-code', machine_fingerprint: fingerprint
      )

      expect(second.id).to eq(first.id)
      expect(described_class.where(machine_fingerprint: fingerprint).count).to eq(1)
    end

    it 'handles concurrent registration gracefully' do
      first = described_class.register(
        user: user, project: project,
        agent_type: 'claude-code', machine_fingerprint: 'e' * 64
      )
      second = described_class.register(
        user: user, project: project,
        agent_type: 'claude-code', machine_fingerprint: 'e' * 64
      )

      expect(second.id).to eq(first.id)
      expect(described_class.where(machine_fingerprint: 'e' * 64).count).to eq(1)
    end
  end

  describe '.owned_by?' do
    it 'returns true when identity belongs to user, project and agent_type' do
      expect(described_class.owned_by?(
        id: identity.id, user: user, project: project, agent_type: 'claude-code'
      )).to be true
    end

    it 'returns false when identity belongs to a different user' do
      other_user = create(:user)

      expect(described_class.owned_by?(
        id: identity.id, user: other_user, project: project, agent_type: 'claude-code'
      )).to be false
    end

    it 'returns false when identity belongs to a different project' do
      other_project = create(:project)

      expect(described_class.owned_by?(
        id: identity.id, user: user, project: other_project, agent_type: 'claude-code'
      )).to be false
    end

    it 'returns false when agent_type does not match' do
      expect(described_class.owned_by?(
        id: identity.id, user: user, project: project, agent_type: 'opencode'
      )).to be false
    end

    it 'returns false when identity is revoked' do
      revoked_identity = create(:ai_agent_identity, user: user, project: project,
        agent_type: 'claude-code', machine_fingerprint: 'c' * 64,
        revoked_at: Time.current)

      expect(described_class.owned_by?(
        id: revoked_identity.id, user: user, project: project, agent_type: 'claude-code'
      )).to be false
    end
  end
end
