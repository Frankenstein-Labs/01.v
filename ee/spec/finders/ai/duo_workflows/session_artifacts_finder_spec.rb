# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SessionArtifactsFinder, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }

  # Access is gated on :read_agent_artifacts, a custom ability granted via
  # member roles (requires the custom_roles license).
  let_it_be(:owner_role) { create(:member_role, :guest, :read_agent_artifacts, namespace: group) }
  let_it_be(:owner_membership) do
    create(:group_member, :guest, member_role: owner_role, user: owner, group: group)
  end

  before do
    stub_licensed_features(
      custom_roles: true,
      project_level_compliance_dashboard: true,
      group_level_compliance_dashboard: true
    )
  end

  subject(:results) do
    described_class.new(current_user: owner, namespace: group, params: {}).execute
  end

  describe '#execute' do
    context 'when ClickHouse is globally enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
      end

      it 'dispatches to ClickHouseFinder' do
        ch_result = instance_double(::ClickHouse::Client::QueryBuilder)
        expect(::Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder)
          .to receive(:new).with(namespace: group, params: {}).and_return(
            instance_double(::Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder, execute: ch_result)
          )

        expect(results).to be(ch_result)
      end
    end

    context 'when ClickHouse is not globally enabled for analytics' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
      end

      it 'dispatches to PostgresqlFinder' do
        pg_result = instance_double(ActiveRecord::Relation)
        expect(::Ai::DuoWorkflows::SessionArtifacts::PostgresqlFinder)
          .to receive(:new).with(namespace: group, params: {}).and_return(
            instance_double(::Ai::DuoWorkflows::SessionArtifacts::PostgresqlFinder, execute: pg_result)
          )

        expect(results).to be(pg_result)
      end
    end

    context 'when the user lacks read_agent_artifacts permission' do
      let(:non_member) { create(:user) }

      it 'returns no results without dispatching' do
        expect(::Ai::DuoWorkflows::SessionArtifacts::PostgresqlFinder).not_to receive(:new)
        expect(::Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder).not_to receive(:new)

        results = described_class.new(current_user: non_member, namespace: group, params: {}).execute

        expect(results).to be_empty
      end
    end

    context 'when custom_roles is not licensed' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns no results' do
        expect(results).to be_empty
      end
    end
  end
end
