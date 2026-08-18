# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::SkipCi, feature_category: :security_policy_management do
  describe '#allowed' do
    context 'when allowed is true' do
      it 'returns true' do
        skip_ci = described_class.new({ allowed: true })
        expect(skip_ci.allowed).to be true
      end
    end

    context 'when allowed is false' do
      it 'returns false' do
        skip_ci = described_class.new({ allowed: false })
        expect(skip_ci.allowed).to be false
      end
    end

    context 'when allowed is not present' do
      it 'returns nil' do
        skip_ci = described_class.new({})
        expect(skip_ci.allowed).to be_nil
      end
    end
  end

  describe '#allowlist' do
    context 'when allowlist is present' do
      it 'returns the allowlist hash' do
        allowlist_data = { users: [{ id: 1 }, { id: 2 }] }
        skip_ci = described_class.new({ allowed: false, allowlist: allowlist_data })
        expect(skip_ci.allowlist).to eq(allowlist_data)
      end
    end

    context 'when allowlist is not present' do
      it 'returns an empty hash' do
        skip_ci = described_class.new({ allowed: true })
        expect(skip_ci.allowlist).to eq({})
      end
    end
  end

  describe '#allowlist_users' do
    context 'when allowlist users is present' do
      it 'returns the users array' do
        users = [{ id: 1 }, { id: 2 }, { id: 3 }]
        skip_ci = described_class.new({ allowed: false, allowlist: { users: users } })
        expect(skip_ci.allowlist_users).to match_array(users)
      end

      it 'handles single user' do
        users = [{ id: 1 }]
        skip_ci = described_class.new({ allowed: false, allowlist: { users: users } })
        expect(skip_ci.allowlist_users).to match_array(users)
      end
    end

    context 'when allowlist users is not present' do
      it 'returns an empty array' do
        skip_ci = described_class.new({ allowed: false, allowlist: {} })
        expect(skip_ci.allowlist_users).to be_empty
      end
    end

    context 'when allowlist is not present' do
      it 'returns an empty array' do
        skip_ci = described_class.new({ allowed: true })
        expect(skip_ci.allowlist_users).to be_empty
      end
    end
  end

  describe 'complete skip_ci configuration' do
    it 'handles skip_ci with allowed false and allowlist' do
      skip_ci_data = {
        allowed: false,
        allowlist: {
          users: [
            { id: 1 },
            { id: 2 },
            { id: 3 }
          ]
        }
      }
      skip_ci = described_class.new(skip_ci_data)

      expect(skip_ci.allowed).to be false
      expect(skip_ci.allowlist_users.length).to eq(3)
      expect(skip_ci.allowlist_users.pluck(:id)).to match_array([1, 2, 3])
    end

    it 'handles skip_ci with allowed true and no allowlist' do
      skip_ci_data = {
        allowed: true
      }
      skip_ci = described_class.new(skip_ci_data)

      expect(skip_ci.allowed).to be true
      expect(skip_ci.allowlist_users).to be_empty
    end
  end
end
