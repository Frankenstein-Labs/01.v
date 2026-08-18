# frozen_string_literal: true

RSpec.shared_examples 'work items linked items blocking relationships' do
  let(:linked_item2) do
    if linked_item.project
      create(:work_item, project: linked_item.project)
    else
      create(:work_item, project: nil, namespace: linked_item.namespace, author: user)
    end
  end

  let(:linked_item3) do
    if linked_item.project
      create(:work_item, project: linked_item.project)
    else
      create(:work_item, project: nil, namespace: linked_item.namespace, author: user)
    end
  end

  before do
    allow(License).to receive(:feature_available?).with(:blocked_work_items).and_return(true)
  end

  it 'adds an item with "blocks" relationship', :aggregate_failures do
    within_testid('work-item-relationships') do
      add_linked_item_ee(linked_item, 'blocks')

      expect(page).to have_css('h3', text: 'Blocking')
      expect(page).to have_link(linked_item.title)
      expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '1')
    end
  end

  it 'adds an item with "is blocked by" relationship', :aggregate_failures do
    within_testid('work-item-relationships') do
      add_linked_item_ee(linked_item, 'is blocked by')

      expect(page).to have_css('h3', text: 'Blocked by')
      expect(page).to have_link(linked_item.title)
      expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '1')
    end
  end

  it 'shows items across all three relationship categories', :aggregate_failures do
    within_testid('work-item-relationships') do
      add_linked_item_ee(linked_item, 'blocks')
      add_linked_item_ee(linked_item2, 'is blocked by')
      add_linked_item_ee(linked_item3, 'relates to')
    end

    within('[data-testid="work-item-linked-items-list"]:nth-child(1)') do
      expect(page).to have_css('h3', text: 'Blocking')
      expect(page).to have_link(linked_item.title)
    end

    within('[data-testid="work-item-linked-items-list"]:nth-child(2)') do
      expect(page).to have_css('h3', text: 'Blocked by')
      expect(page).to have_link(linked_item2.title)
    end

    within('[data-testid="work-item-linked-items-list"]:nth-child(3)') do
      expect(page).to have_css('h3', text: 'Related to')
      expect(page).to have_link(linked_item3.title)
    end

    expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '3')
  end

  it 'moves an item between relationship categories via drag-and-drop', :aggregate_failures do
    within_testid('work-item-relationships') do
      add_linked_item_ee(linked_item, 'blocks')
      add_linked_item_ee(linked_item2, 'relates to')
    end

    within_testid('work-item-relationships') do
      expect(page).to have_css('[data-testid="work-item-linked-items-list"]', text: 'Blocking')
      expect(page).to have_css('[data-testid="work-item-linked-items-list"]', text: 'Related to')
    end

    from_item = find('[data-testid="work-item-linked-items-list"]', text: 'Blocking').find('li.linked-item')
    to_item = find('[data-testid="work-item-linked-items-list"]', text: 'Related to').find('li.linked-item')

    from_item.drag_to(to_item)

    within_testid('work-item-relationships') do
      expect(page).not_to have_css('h3', text: 'Blocking')
      expect(page).to have_css('h3', text: 'Related to')
      expect(page).to have_link(linked_item.title)
    end
  end

  def add_linked_item_ee(item, relationship_type)
    click_button 'Add'

    within_testid('link-work-item-form') do
      fill_in 'Search existing items', with: item.title
      click_button item.title
      choose relationship_type
      expect(page).to have_button('Add', disabled: false)
      click_button 'Add'
    end

    expect(page).to have_link(item.title)
  end
end
