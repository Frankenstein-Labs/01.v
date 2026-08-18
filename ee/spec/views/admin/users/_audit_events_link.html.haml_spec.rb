# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_audit_events_link.html.haml', feature_category: :audit_events do
  let_it_be(:user) { build_stubbed(:user, username: 'testuser') }

  context 'when admin_audit_log license feature is available' do
    before do
      stub_licensed_features(admin_audit_log: true)
    end

    it 'renders the audit events link' do
      render partial: 'admin/users/audit_events_link', locals: { user: user }

      expect(rendered).to have_text('Audit events:')
      expect(rendered).to have_link('View logs', href: '/admin/audit_logs?entity_type=User&entity_username=testuser')
    end
  end

  context 'when admin_audit_log license feature is not available' do
    before do
      stub_licensed_features(admin_audit_log: false)
    end

    it 'does not render anything' do
      render partial: 'admin/users/audit_events_link', locals: { user: user }

      expect(rendered).to be_empty
    end
  end
end
