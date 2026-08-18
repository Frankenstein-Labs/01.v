# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::IdentityVerificationComponent, :aggregate_failures, feature_category: :duo_chat do
  let(:user_namespace) { build_stubbed(:namespace) }
  let(:user) { build_stubbed(:user, namespace: user_namespace) }
  let(:record) { nil }
  let(:container) { instance_double(DuoChatPanel::Container, type: container_type, record: record) }
  let(:container_type) { 'group' }

  subject(:component) { render_inline(described_class.new(container: container, user: user)) && page }

  describe 'rendering' do
    it 'renders the #duo-chat-panel.duo-chat-panel element' do
      is_expected.to have_selector('#duo-chat-panel.duo-chat-panel')
    end

    it 'sets the identity-verification-required data attribute' do
      is_expected.to have_css('#duo-chat-panel[data-identity-verification-required="true"]')
    end

    it 'sets the identity-verification-path data attribute' do
      is_expected.to have_css(
        "#duo-chat-panel[data-identity-verification-path='#{Gitlab::Routing.url_helpers.identity_verification_path}']"
      )
    end

    context 'when container has no record (nil)' do
      it 'defaults the container-type data attribute to group' do
        is_expected.to have_css('#duo-chat-panel[data-container-type="group"]')
      end
    end

    context 'when within a project' do
      let(:record) { build(:project) }
      let(:container_type) { 'project' }

      it 'sets the correct container-type data attribute' do
        is_expected.to have_css('#duo-chat-panel[data-container-type="project"]')
      end
    end

    context 'when within a group' do
      let(:record) { build(:group) }
      let(:container_type) { 'group' }

      it 'sets the correct container-type data attribute' do
        is_expected.to have_css('#duo-chat-panel[data-container-type="group"]')
      end
    end
  end

  describe '#data' do
    it_behaves_like 'sets auto_expand field with respect to the legacy callout'
  end
end
