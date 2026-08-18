# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRules::GovernanceSurface, feature_category: :ai_agents do
  let_it_be(:container) { create(:group) }

  # The Duo Developer flow's real reference; a literal here guards the allowlist against drift.
  let(:duo_developer_flow) { 'developer/v1' }

  describe '.for' do
    context 'when the background-governance flag is enabled' do
      it 'returns :background for a background environment with an allowlisted flow' do
        %w[web ambient].each do |env|
          expect(
            described_class.for(environment: env, container: container, workflow_definition: duo_developer_flow)
          ).to eq(:background)
        end
      end

      it 'returns nil for a reference that is not a catalog flow, even with an allowlisted base name' do
        expect(
          described_class.for(environment: 'web', container: container, workflow_definition: 'developer/not-a-flow')
        ).to be_nil
      end

      it 'returns nil for a background environment when the flow is not allowlisted' do
        %w[web ambient].each do |env|
          expect(
            described_class.for(environment: env, container: container, workflow_definition: 'security_review/v1')
          ).to be_nil
        end
      end

      it 'returns nil for a background environment when no flow is given' do
        expect(described_class.for(environment: 'ambient', container: container)).to be_nil
      end

      it 'never returns :background for a non-background environment even with an allowlisted flow' do
        %w[ide chat chat_partial].each do |env|
          expect(
            described_class.for(environment: env, container: container, workflow_definition: duo_developer_flow)
          ).not_to eq(:background)
        end
      end

      it 'returns nil for a nil environment' do
        expect(
          described_class.for(environment: nil, container: container, workflow_definition: duo_developer_flow)
        ).to be_nil
      end

      it 'evaluates the flag against the root ancestor for a project container' do
        project = create(:project, group: container)

        expect(
          described_class.for(environment: 'web', container: project, workflow_definition: duo_developer_flow)
        ).to eq(:background)
      end
    end

    context 'when the background-governance flag is disabled' do
      before do
        stub_feature_flags(duo_workflow_background_tool_governance: false)
      end

      it 'returns nil even for an allowlisted background flow' do
        expect(
          described_class.for(environment: 'web', container: container, workflow_definition: duo_developer_flow)
        ).to be_nil
      end
    end

    context 'for local environments' do
      it 'returns the environment as the surface' do
        %w[ide chat chat_partial].each do |env|
          expect(described_class.for(environment: env, container: container)).to eq(env.to_sym)
        end
      end

      it 'returns nil for an environment outside the local allowlist' do
        expect(described_class.for(environment: 'external', container: container)).to be_nil
      end

      it 'never resolves a background environment as a local surface' do
        # `web` with a non-allowlisted flow falls through background resolution
        # and must stay on the caller's default, not become a local surface.
        expect(
          described_class.for(environment: 'web', container: container, workflow_definition: 'security_review/v1')
        ).to be_nil
      end

      it 'returns nil for a blank environment' do
        expect(described_class.for(environment: '', container: container)).to be_nil
      end

      it 'evaluates the flag against the root ancestor for a project container' do
        project = create(:project, group: container)

        expect(described_class.for(environment: 'ide', container: project)).to eq(:ide)
      end

      context 'when the local-governance flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_local_tool_governance: false)
        end

        it 'returns nil so the caller default applies' do
          expect(described_class.for(environment: 'ide', container: container)).to be_nil
        end

        it 'does not affect background resolution' do
          expect(
            described_class.for(environment: 'web', container: container, workflow_definition: duo_developer_flow)
          ).to eq(:background)
        end
      end
    end
  end
end
