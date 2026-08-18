# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BasePolicy, feature_category: :system_access do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper

  let(:auditor) { build(:auditor) }

  subject { described_class.new(auditor, nil) }

  describe 'read cross project' do
    context 'when an external authorization service is enabled' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows auditors' do
        expect_allowed(:read_cross_project)
      end
    end
  end

  describe 'read all resources' do
    it 'allows auditors' do
      expect_allowed(:read_all_resources)
    end
  end

  describe 'admin all resources' do
    it 'forbids auditors' do
      expect_disallowed(:admin_all_resources)
    end
  end
end
