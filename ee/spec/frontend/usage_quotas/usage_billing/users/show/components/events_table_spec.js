import { GlTableLite, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EventsTable from 'ee/usage_quotas/usage_billing/users/show/components/events_table.vue';
import UserDate from '~/vue_shared/components/user_date.vue';

describe('EventsTable', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockEvents = [
    {
      timestamp: '2023-12-01T10:30:00Z',
      flowType: 'Code Completion',
      location: {
        name: 'gitlab-org/gitlab',
        webUrl: 'https://gitlab.com/gitlab-org/gitlab',
      },
      creditsUsed: 1500,
      sessionLink: 'https://gitlab.com/gitlab-org/gitlab/-/automate/agent-sessions/101',
    },
    {
      timestamp: '2023-12-01T09:15:00Z',
      flowType: 'Code Generation',
      location: {
        name: 'gitlab-org/gitlabhq',
        webUrl: 'https://gitlab.com/gitlab-org/gitlabhq',
      },
      creditsUsed: 75.3333,
      sessionLink: null,
    },
    {
      timestamp: '2023-12-01T08:45:00Z',
      eventType: 'Chat',
      location: null,
      creditsUsed: 25,
      sessionLink: null,
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = mountExtended(EventsTable, {
      propsData: {
        events: mockEvents,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().find('tbody').findAll('tr');
  const findFirstRowCells = () => findTableRows().at(0).findAll('td');

  describe('when events are provided', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the table with correct number of rows', () => {
      expect(findTableRows()).toHaveLength(mockEvents.length);
    });

    it('renders table with correct field headers', () => {
      const tableFields = findTable().props('fields');

      expect(tableFields).toEqual([
        { key: 'timestamp', label: 'Date/Time' },
        { key: 'action', label: 'Action' },
        { key: 'location', label: 'Location' },
        { key: 'creditsUsed', label: 'Credit amount' },
      ]);
    });

    describe('cells rendering', () => {
      /** @type {import('@vue/test-utils').WrapperArray,} */
      let firstRowCells;

      beforeEach(() => {
        firstRowCells = findFirstRowCells();
      });

      it('renders the date and time', () => {
        expect(firstRowCells.at(0).findComponent(UserDate).exists()).toBe(true);
        expect(firstRowCells.at(0).findComponent(UserDate).props('date')).toBe(
          mockEvents[0].timestamp,
        );
      });

      it('renders action as link when sessionLink is present', () => {
        const actionLink = firstRowCells.at(1).findComponent(GlLink);
        expect(actionLink.exists()).toBe(true);
        expect(actionLink.attributes('href')).toBe(mockEvents[0].sessionLink);
        expect(actionLink.text()).toBe(mockEvents[0].flowType);
      });

      it('renders action as plain text when sessionLink is not present', () => {
        const secondRowCells = findTableRows().at(1).findAll('td');
        const actionCell = secondRowCells.at(1);
        expect(actionCell.findComponent(GlLink).exists()).toBe(false);
        expect(actionCell.text()).toBe(mockEvents[1].flowType);
      });

      it('renders action from eventType if flowType is not present', () => {
        expect(findTableRows().at(2).findAll('td').at(1).text()).toBe(mockEvents[2].eventType);
      });

      describe('location cell', () => {
        it('renders location', () => {
          const locationLink = firstRowCells.at(2).findComponent(GlLink);
          expect(locationLink.exists()).toBe(true);
          expect(locationLink.attributes('href')).toBe(mockEvents[0].location.webUrl);
          expect(locationLink.text()).toBe(mockEvents[0].location.name);
        });

        it('renders nothing when location is null', () => {
          const thirdRowCells = findTableRows().at(2).findAll('td');
          const locationCell = thirdRowCells.at(2);

          expect(locationCell.findComponent(GlLink).exists()).toBe(false);
          expect(locationCell.text()).toBe('');
        });
      });

      describe('credits used cell', () => {
        it('renders credits amount', () => {
          expect(firstRowCells.at(3).text()).toBe('1.5k');
        });

        it('formats fractional number', () => {
          const secondRowCells = findTableRows().at(1).findAll('td');
          expect(secondRowCells.at(3).text()).toBe('75.33');
        });
      });
    });
  });

  describe('when no events are provided', () => {
    beforeEach(() => {
      createComponent({ events: [] });
    });

    it('renders table with no rows', () => {
      expect(findTableRows()).toHaveLength(0);
    });
  });
});
