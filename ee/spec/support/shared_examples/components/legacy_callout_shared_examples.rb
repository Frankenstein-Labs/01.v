# frozen_string_literal: true

RSpec.shared_examples 'sets auto_expand field with respect to the legacy callout' do
  describe 'auto_expand field' do
    context 'when user is not signed in' do
      let(:user) { nil }

      it 'is "false"' do
        is_expected.to have_css('#duo-chat-panel[data-auto-expand="false"]')
      end
    end

    context 'when user has not dismissed the callout' do
      it 'is "true"' do
        is_expected.to have_css('#duo-chat-panel[data-auto-expand="true"]')
      end
    end

    context 'when user has dismissed the legacy callout' do
      let(:user) do
        build_stubbed(:user, callouts: [
          build_stubbed(:callout, feature_name: 'duo_panel_empty_state_auto_expanded')
        ])
      end

      it 'is "false"' do
        is_expected.to have_css('#duo-chat-panel[data-auto-expand="false"]')
      end
    end

    context 'when user has dismissed the callout' do
      let(:user) do
        build_stubbed(:user, callouts: [
          build_stubbed(:callout, feature_name: 'duo_panel_auto_expanded')
        ])
      end

      it 'is "false"' do
        is_expected.to have_css('#duo-chat-panel[data-auto-expand="false"]')
      end
    end
  end
end
