# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::Modes::Dap, feature_category: :duo_code_review do
  subject(:mode) { described_class.new(user: user, container: container) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:container) { project }

  describe '#mode' do
    it 'returns the mode name' do
      expect(mode.mode).to eq(:dap)
    end
  end

  describe '#enabled?' do
    it 'always returns true' do
      expect(mode).to be_enabled
    end
  end

  describe '#active?' do
    let(:user_is_duo_enterprise) { false }
    let(:duo_agent_platform_available) { true }
    let(:duo_code_review_dap_available) { true }

    before do
      if user
        allow(user).to receive(:assigned_to_duo_enterprise?)
          .with(container)
          .and_return(user_is_duo_enterprise)
      end

      allow(::Ai::DuoAgentPlatform).to receive(:available?)
        .with(user: user, container: container)
        .and_return(duo_agent_platform_available)

      allow(container).to receive(:duo_code_review_dap_available?)
        .and_return(duo_code_review_dap_available)
    end

    shared_examples 'not active' do
      it { expect(mode).not_to be_active }
    end

    shared_examples 'active' do
      it { expect(mode).to be_active }
    end

    context 'when there is no user' do
      let(:user) { nil }

      include_examples 'not active'
    end

    context 'when user does not have a Duo Enterprise add-on' do
      include_examples 'active'

      context 'when DuoAgentPlatform is not available' do
        let(:duo_agent_platform_available) { false }

        include_examples 'not active'
      end

      context 'when DAP code review is disabled for the container' do
        let(:duo_code_review_dap_available) { false }

        include_examples 'not active'
      end
    end

    context 'when user has a Duo Enterprise add-on' do
      let(:user_is_duo_enterprise) { true }

      context 'when duo_code_review_dap_internal_users is enabled for the user' do
        # Fast-path: internal users bypass consent; falls through to DuoAgentPlatform check.

        include_examples 'active'

        context 'when DuoAgentPlatform is not available' do
          let(:duo_agent_platform_available) { false }

          include_examples 'not active'
        end

        context 'when DAP code review is disabled for the container' do
          let(:duo_code_review_dap_available) { false }

          include_examples 'not active'
        end
      end

      context 'when duo_code_review_dap_internal_users is disabled' do
        before do
          stub_feature_flags(duo_code_review_dap_internal_users: false)
        end

        context 'when the namespace has not consented' do
          before do
            allow(group).to receive(:consented_to?)
              .with(:code_review_flow_dap_routing)
              .and_return(false)
          end

          include_examples 'not active'
        end

        context 'when the namespace has consented' do
          before do
            allow(group).to receive(:consented_to?)
              .with(:code_review_flow_dap_routing)
              .and_return(true)
          end

          include_examples 'active'

          context 'when DuoAgentPlatform is not available' do
            let(:duo_agent_platform_available) { false }

            include_examples 'not active'
          end

          context 'when DAP code review is disabled for the container' do
            let(:duo_code_review_dap_available) { false }

            include_examples 'not active'
          end
        end
      end
    end
  end
end
