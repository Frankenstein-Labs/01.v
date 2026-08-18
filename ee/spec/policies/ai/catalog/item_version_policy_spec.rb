# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersionPolicy, :with_current_organization, feature_category: :workflow_catalog do
  let(:user) { nil }
  let(:item_version) { build_stubbed(:ai_catalog_item_version) }

  subject(:policy) { described_class.new(user, item_version) }

  it { is_expected.to delegate_to(Ai::Catalog::ItemPolicy) }
end
