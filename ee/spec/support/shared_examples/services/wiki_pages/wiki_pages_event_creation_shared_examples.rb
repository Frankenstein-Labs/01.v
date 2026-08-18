# frozen_string_literal: true

RSpec.shared_examples 'WikiPages::Create|Update|DestroyService#execute group wiki event' do
  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group, :wiki_repo, owners: [user]) }

  before do
    stub_licensed_features(group_wikis: true)
  end

  it 'sets group_id and leaves personal_namespace_id null', :aggregate_failures do
    expect { service_execute }.to change { Event.count }.by(1)

    expect(Event.recent.first).to have_attributes(group_id: group.id, personal_namespace_id: nil,
      target_type: 'WikiPage::Meta')
  end
end
