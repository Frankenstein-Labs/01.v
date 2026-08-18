# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPages::CreateService, feature_category: :wiki do
  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute sends a Geo event update' do
    let(:opts) { { title: 'Title', content: 'Content for wiki page', format: 'markdown' } }

    subject(:service_execute) { described_class.new(container: container, current_user: user, params: opts).execute }
  end

  it_behaves_like 'WikiPages::CreateService#execute', :group

  it_behaves_like 'WikiPages::Create|Update|DestroyService#execute group wiki event' do
    subject(:service_execute) do
      described_class.new(container: group, current_user: group.owners.first,
        params: { title: 'Title', content: 'Content', format: 'markdown' }).execute
    end
  end
end
