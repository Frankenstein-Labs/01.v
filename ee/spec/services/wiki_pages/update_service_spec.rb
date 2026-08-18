# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPages::UpdateService, feature_category: :wiki do
  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute sends a Geo event update' do
    let(:page) { create(:wiki_page, project: container) }
    let(:opts) { { content: 'New content for wiki page', format: 'markdown', message: 'New wiki message' } }

    subject(:service_execute) do
      described_class.new(container: container, current_user: user, params: opts).execute(page)
    end
  end

  it_behaves_like 'WikiPages::UpdateService#execute', :group

  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute group wiki event' do
    let(:page) { create(:wiki_page, container: group) }

    subject(:service_execute) do
      described_class.new(container: group, current_user: group.owners.first,
        params: { title: 'New Title', content: 'New content', format: 'markdown' }).execute(page)
    end
  end
end
