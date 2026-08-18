# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/work_items/show.html.haml', feature_category: :team_planning do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }

  before do
    assign(:group, group)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:breadcrumb_title)
    allow(view).to receive(:page_title)
  end

  it 'sets "Work items settings" as page title' do
    render

    expect(view).to have_received(:page_title).with(s_("WorkItem|Work items settings"))
  end

  it 'sets "Work items settings" as breadcrumb title' do
    render

    expect(view).to have_received(:breadcrumb_title).with(s_("WorkItem|Work items settings"))
  end
end
