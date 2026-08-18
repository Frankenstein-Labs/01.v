# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/hook_logs/show', feature_category: :webhooks do
  let(:web_hook) { build_stubbed(:group_hook) }
  let(:web_hook_log) { build_stubbed(:web_hook_log, web_hook: web_hook) }

  before do
    assign :group, web_hook.group
    assign :hook, web_hook
    assign :hook_log, web_hook_log
    render
  end

  it 'renders the request details page' do
    expect(rendered).to have_text('Request details')
    expect(rendered).to have_text('Resend Request')
  end
end
