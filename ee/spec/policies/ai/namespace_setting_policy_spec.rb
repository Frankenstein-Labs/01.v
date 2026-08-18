# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::NamespaceSettingPolicy, feature_category: :duo_chat do
  subject(:policy) { described_class.new(current_user, namespace_setting) }

  let_it_be(:namespace) { create(:group) }
  let_it_be(:namespace_setting) { create(:namespace_ai_settings, namespace: namespace) }
  let_it_be(:current_user) { create(:user) }

  it 'is instantiable with a namespace setting' do
    expect(policy).to be_a(described_class)
  end
end
