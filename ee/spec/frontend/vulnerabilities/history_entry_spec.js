import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import HistoryEntry from 'ee/vulnerabilities/components/history_entry.vue';

describe('History Entry', () => {
  let wrapper;

  const systemNote = {
    system: true,
    id: 1,
    body: 'changed vulnerability status to [dismissed](https://example.com)',
    bodyHtml: '<p>changed vulnerability status to <a href="https://example.com">dismissed</a></p>',
    systemNoteIconName: 'cancel',
    createdAt: '2021-08-25T16:19:10Z',
    updatedAt: '2021-08-25T16:21:18Z',
    author: {
      name: 'author name',
      username: 'author username',
      status_tooltip_html: '<span class="status">status_tooltip_html</span>',
    },
  };

  const commentNote = {
    id: 2,
    body: 'some note',
    author: {},
  };

  const createWrapper = (...notes) => {
    const discussion = { notes };

    wrapper = shallowMountExtended(HistoryEntry, {
      propsData: {
        discussion,
      },
      stubs: { EventItem },
    });
  };

  const createBorderlessWrapper = (...notes) => {
    wrapper = shallowMountExtended(HistoryEntry, {
      propsData: {
        discussion: { notes },
        borderless: true,
      },
      stubs: { EventItem },
    });
  };

  const eventItem = () => wrapper.findComponent(EventItem);
  const newComment = () => wrapper.findByTestId('new-comment');
  const existingComments = () => wrapper.findAllComponentsByTestId('existing-comment');
  const commentAt = (index) => existingComments().at(index);

  it('passes the expected values to the event item component', () => {
    createWrapper(systemNote);

    expect(eventItem().html()).toContain(
      'changed vulnerability status to <a href="https://example.com">dismissed</a>',
    );
    expect(eventItem().props()).toMatchObject({
      id: systemNote.id,
      author: systemNote.author,
      createdAt: systemNote.createdAt,
      iconName: systemNote.systemNoteIconName,
      isSystemNote: true,
    });
  });

  it('does not show anything if there is no system note', () => {
    createWrapper();

    expect(wrapper.find('*').exists()).toBe(false);
  });

  it('shows the add comment button where there are no comments', () => {
    createWrapper(systemNote);

    expect(newComment().exists()).toBe(true);
    expect(existingComments()).toHaveLength(0);
  });

  it('displays comments when there are comments', () => {
    const commentNoteClone = { ...commentNote, id: 3, note: 'different note' };
    createWrapper(systemNote, commentNote, commentNoteClone);

    expect(newComment().exists()).toBe(false);
    expect(existingComments()).toHaveLength(2);
    expect(commentAt(0).props('comment')).toEqual(commentNote);
    expect(commentAt(1).props('comment')).toEqual(commentNoteClone);
  });

  it('still renders the entry content when borderless', () => {
    createBorderlessWrapper(systemNote);

    expect(eventItem().exists()).toBe(true);
    expect(newComment().exists()).toBe(true);
  });
});
