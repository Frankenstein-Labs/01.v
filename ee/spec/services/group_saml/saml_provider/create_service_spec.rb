# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupSaml::SamlProvider::CreateService, feature_category: :system_access do
  let(:current_user) { build_stubbed(:user) }
  let(:group) { create :group }
  let(:audit_event_name) { 'group_saml_provider_create' }

  subject(:service) { described_class.new(current_user, group, params: params) }

  include_examples 'base SamlProvider service'
end
