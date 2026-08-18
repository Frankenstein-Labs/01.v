# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleWorker, feature_category: :permissions do
  describe '#perform' do
    subject(:perform_worker) { described_class.new.perform }

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    it 'has the option to reschedule once if deduplicated and a TTL' do
      expect(described_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once })
    end

    context 'without provider argument' do
      it 'calls execute_all_providers sync class method' do
        expect(::Gitlab::Authz::Ldap::Sync::AdminRole).to receive(:execute_all_providers)

        perform_worker
      end
    end
  end
end
