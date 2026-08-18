import { GlAlert, GlKeysetPagination, GlLoadingIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SessionAuditEventsList from 'ee/agent_artifacts/components/session_audit_events_list.vue';

const mockAuthor = {
  id: 'gid://gitlab/User/1',
  name: 'Scott Hampton',
  username: 'shampton',
  avatarUrl: 'https://gitlab.com/uploads/-/system/user/avatar/1/avatar.png',
  webPath: '/shampton',
  __typename: 'UserCore',
};

const mockEvents = [
  {
    id: 'event-1',
    eventName: 'tool_execution',
    createdAt: '2026-05-04T10:30:00Z',
    details: { toolName: 'file_write', action: 'created file' },
    ipAddress: '127.0.0.1',
    workflowId: '1',
    author: mockAuthor,
    __typename: 'AiAuditEvent',
  },
  {
    id: 'event-2',
    eventName: 'tool_execution',
    createdAt: '2026-05-04T10:31:00Z',
    details: { toolName: 'read_file', action: 'read file' },
    ipAddress: '127.0.0.1',
    workflowId: '1',
    author: mockAuthor,
    __typename: 'AiAuditEvent',
  },
];

const mockDefaultPageInfo = {
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'event-1',
  endCursor: 'event-2',
  __typename: 'PageInfo',
};

describe('SessionAuditEventsList', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(SessionAuditEventsList, {
      propsData: {
        events: mockEvents,
        pageInfo: mockDefaultPageInfo,
        isLoading: false,
        hasError: false,
        ...props,
      },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findTimeline = () => wrapper.findByTestId('audit-events-timeline');
  const findEventItems = () => wrapper.findAll('.timeline-entry');
  const findEmptyState = () => wrapper.findByTestId('empty-state');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findTitle = () => wrapper.find('h5');
  const findRows = () => wrapper.findAllByTestId('audit-event-row');

  it('renders the section title', () => {
    createComponent();

    expect(findTitle().text()).toBe('Audit events');
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true, events: [] });
    });

    it('shows loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not show the timeline', () => {
      expect(findTimeline().exists()).toBe(false);
    });

    it('does not show an error alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when there is an error', () => {
    beforeEach(() => {
      createComponent({ hasError: true, events: [] });
    });

    it('shows an error alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Failed to load audit events.');
    });

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not show the timeline', () => {
      expect(findTimeline().exists()).toBe(false);
    });
  });

  describe('when data is loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('hides loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the timeline with events', () => {
      expect(findTimeline().exists()).toBe(true);
      expect(findEventItems()).toHaveLength(2);
    });

    it('renders formatted event name for each event', () => {
      const eventNames = wrapper.findAllByTestId('event-name');
      expect(eventNames.at(0).text()).toBe('Tool execution');
      expect(eventNames.at(1).text()).toBe('Tool execution');
    });

    it('renders event date for each event', () => {
      const eventDates = wrapper.findAllByTestId('event-date');
      expect(eventDates.at(0).text()).toContain('2026');
    });

    it('renders author name for each event', () => {
      const authors = wrapper.findAllByTestId('event-author');
      expect(authors.at(0).text()).toBe('Scott Hampton');
    });

    it('renders author link for each event', () => {
      const authors = wrapper.findAllByTestId('event-author');
      expect(authors.at(0).attributes('href')).toBe('/shampton');
    });
  });

  describe('empty state', () => {
    beforeEach(() => {
      createComponent({
        events: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          __typename: 'PageInfo',
        },
      });
    });

    it('shows empty state message', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().text()).toBe('No audit events found.');
    });

    it('does not show the timeline', () => {
      expect(findTimeline().exists()).toBe(false);
    });
  });

  describe('pagination', () => {
    describe('when pages are available', () => {
      beforeEach(() => {
        createComponent({
          pageInfo: { ...mockDefaultPageInfo, hasNextPage: true },
        });
      });

      it('renders pagination', () => {
        expect(findPagination().exists()).toBe(true);
      });

      it('emits next when pagination emits next', () => {
        findPagination().vm.$emit('next', 'event-2');

        expect(wrapper.emitted('next')).toEqual([['event-2']]);
      });

      it('emits prev when pagination emits prev', () => {
        findPagination().vm.$emit('prev', 'event-1');

        expect(wrapper.emitted('prev')).toEqual([['event-1']]);
      });
    });

    describe('when no pages are available', () => {
      it('does not render pagination', () => {
        createComponent();

        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('row selection', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits select with the event when a row is clicked', () => {
      findRows().at(0).trigger('click');

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toMatchObject({ id: 'event-1' });
    });

    it('emits select with the event when Enter is pressed on a row', () => {
      findRows().at(1).trigger('keydown.enter');

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toMatchObject({ id: 'event-2' });
    });

    it('emits select with the event when Space is pressed on a row', () => {
      findRows().at(0).trigger('keydown.space');

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toMatchObject({ id: 'event-1' });
    });

    it('does not emit select when the author link is clicked', () => {
      const authorLink = wrapper.findAllByTestId('event-author').at(0);
      // The author <a> would navigate; jsdom can't and logs after teardown,
      // failing CI. Cancel the default so only the @click.stop guard is exercised.
      authorLink.element.addEventListener('click', (event) => event.preventDefault());

      authorLink.trigger('click');

      expect(wrapper.emitted('select')).toBeUndefined();
    });
  });
});
