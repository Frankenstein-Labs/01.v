# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPages::DestroyService, feature_category: :wiki do
  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute sends a Geo event update' do
    let(:page) { create(:wiki_page, project: container) }

    subject(:service_execute) { described_class.new(container: container, current_user: user).execute(page) }
  end

  it_behaves_like 'WikiPages::DestroyService#execute', :group

  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute group wiki event' do
    let(:page) { create(:wiki_page, container: group) }

    subject(:service_execute) do
      described_class.new(container: group, current_user: group.owners.first).execute(page)
    end
  end
end
