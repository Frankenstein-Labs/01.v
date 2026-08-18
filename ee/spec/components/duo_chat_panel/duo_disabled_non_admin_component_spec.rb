# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DuoChatPanel::DuoDisabledNonAdminComponent, :aggregate_failures, feature_category: :duo_chat do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }
  let(:container) do
    instance_double(
      DuoChatPanel::Container,
      type: 'group',
      project?: false,
      project_id: nil,
      namespace_id: group.to_global_id.to_s,
      record: group
    )
  end

  let(:expected_data_attributes) do
    {
      is_duo_disabled_non_admin: true,
      agentic_available: true,
      container_type: 'group',
      namespace_id: group.to_global_id
    }
  end

  subject(:component) do
    render_inline(
      described_class.new(container: container, user: user)
    ) && page
  end

  it 'renders the #duo-chat-panel element' do
    is_expected.to have_selector('#duo-chat-panel')
  end

  it 'has the duo-chat-panel class' do
    is_expected.to have_selector('.duo-chat-panel')
  end

  it 'renders with correct data attributes' do
    expect_duo_chat_panel_attributes(expected_data_attributes)
    is_expected.not_to have_css('#duo-chat-panel[data-project-id]')
  end

  context 'when container is a Project' do
    let(:project) { build_stubbed(:project) }
    let(:container) do
      instance_double(
        DuoChatPanel::Container,
        type: 'project',
        project?: true,
        project_id: project.to_global_id.to_s,
        namespace_id: nil,
        record: project
      )
    end

    let(:expected_data_attributes) do
      {
        is_duo_disabled_non_admin: true,
        agentic_available: true,
        container_type: 'project',
        project_id: project.to_global_id
      }
    end

    it 'renders the #duo-chat-panel element' do
      is_expected.to have_selector('#duo-chat-panel')
    end

    it 'renders with correct data attributes' do
      expect_duo_chat_panel_attributes(expected_data_attributes)
      is_expected.not_to have_css('#duo-chat-panel[data-namespace-id]')
    end
  end

  def expect_duo_chat_panel_attributes(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected
        .to have_selector("#duo-chat-panel[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
