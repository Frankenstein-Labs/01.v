# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_duo_chat_panel', feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:group) { build(:group) }

  before do
    allow(view).to receive_messages(
      current_user: user
    )
    assign(:group, group)

    allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)

    allow_next_instance_of(::Gitlab::Llm::DuoChat) do |instance|
      allow(instance).to receive(:show_duo_entry_point?)
        .and_return(duo_enabled)
      allow(instance).to receive_messages(
        agentic_mode_available?: false,
        classic_chat_available?: false,
        credits_available?: true
      )
    end
  end

  context 'when duo is enabled' do
    let(:amazon_q_enabled) { false }
    let(:duo_enabled) { true }

    it 'renders the ai panel' do
      render

      expect(rendered).to have_css('#duo-chat-panel')
    end
  end

  context 'when amazon_q is enabled' do
    let(:amazon_q_enabled) { true }
    let(:duo_enabled) { true }

    it 'does not render the ai panel' do
      render

      expect(rendered).to have_css('#duo-chat-panel')
    end
  end

  context 'when duo is disabled' do
    let(:amazon_q_enabled) { false }
    let(:duo_enabled) { false }

    it 'renders the panel in access-denied mode' do
      render

      expect(rendered).to have_css('#duo-chat-panel[data-access-denied="true"]')
    end

    context 'when the user is anonymous' do
      let(:user) { nil }

      it 'does not render the panel' do
        render

        expect(rendered).not_to have_css('#duo-chat-panel')
      end
    end

    context 'when duo is disabled at instance level (always off)' do
      let(:amazon_q_enabled) { false }
      let(:duo_enabled) { false }

      before do
        stub_application_setting(duo_features_enabled: false, lock_duo_features_enabled: true)
      end

      it 'does not render anything' do
        render

        expect(rendered).not_to have_css('#duo-chat-panel')
      end
    end

    context 'when duo is disabled by default but not locked (default_off)' do
      let(:amazon_q_enabled) { false }
      let(:duo_enabled) { false }

      before do
        stub_application_setting(duo_features_enabled: false, lock_duo_features_enabled: false)
      end

      it 'renders the panel in access-denied mode' do
        render

        expect(rendered).to have_css('#duo-chat-panel[data-access-denied="true"]')
      end
    end
  end
end
