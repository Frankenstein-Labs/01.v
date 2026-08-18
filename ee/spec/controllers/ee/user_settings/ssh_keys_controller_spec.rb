# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserSettings::SshKeysController, feature_category: :user_profile do
  let(:user) { create(:user) }

  describe '#create' do
    it 'logs the audit event' do
      stub_licensed_features(extended_audit_events: true)

      sign_in(user)

      key = build(:key)

      expect { post :create, params: { key: key.attributes } }.to change { AuditEventReader.count }.by(1)
    end
  end
end
