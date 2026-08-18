# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/virtual_registries/maven/registries_and_upstreams/index', feature_category: :virtual_registry do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }

  before do
    assign(:group, group)
    allow(view).to receive_messages(
      current_user: user,
      can?: false,
      can_create_virtual_registry?: false,
      maven_registries_and_upstreams_data: '{}'
    )
    allow(::VirtualRegistries).to receive(:registries_count_for).and_return(0)
  end

  it 'renders the page heading' do
    render

    expect(rendered).to have_selector('h1', text: 'Maven virtual registries')
  end

  it 'renders description about registry limits' do
    render

    expect(rendered).to have_text('You can add up to 20 registries per top-level group.')
  end

  it 'passes correct data to Vue component' do
    expected_data = { fullPath: group.full_path }.to_json
    allow(view).to receive(:maven_registries_and_upstreams_data).with(group).and_return(expected_data)

    render

    expect(rendered).to have_selector("#js-vue-maven-virtual-registries-and-upstreams[data-provide='#{expected_data}']")
  end

  context 'when user can create virtual registry' do
    before do
      allow(view).to receive(:can_create_virtual_registry?).and_return(true)
    end

    context 'when registry count is below maximum' do
      before do
        stub_const('VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT', 5)
        allow(::VirtualRegistries).to receive(:registries_count_for).with(group, registry_type: 'maven').and_return(2)
      end

      it 'renders create registry button' do
        render

        expect(rendered).to have_link('Create registry', href: new_group_virtual_registries_maven_registry_path(group))
      end
    end

    context 'when registry count is at maximum' do
      before do
        stub_const('VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT', 5)
        allow(::VirtualRegistries).to receive(:registries_count_for).with(group, registry_type: 'maven').and_return(5)
        allow(view).to receive(:max_maven_registries_count_exceeded?).with(group).and_return(true)
      end

      it 'does not render create registry button' do
        render

        expect(rendered).not_to have_link('Create registry')
      end

      it 'renders maximum registries reached message' do
        render

        expect(rendered).to have_text('Maximum number of registries reached.')
      end
    end
  end

  context 'when user cannot create virtual registry' do
    it 'does not render create registry button' do
      render

      expect(rendered).not_to have_link('Create registry')
    end
  end
end
