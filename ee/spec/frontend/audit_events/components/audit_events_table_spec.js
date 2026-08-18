import { GlKeysetPagination, GlTable } from '@gitlab/ui';
import { mount } from '@vue/test-utils';

import { nextTick } from 'vue';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import AuditEventsTable from 'ee/audit_events/components/audit_events_table.vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { visitUrl } from '~/lib/utils/url_utility';
import createEvents from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

const EVENTS = createEvents();

describe('AuditEventsTable component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return mount(AuditEventsTable, {
      propsData: {
        events: EVENTS,
        isLastPage: false,
        ...props,
      },
    });
  };

  const getCell = (trIdx, tdIdx) => {
    return wrapper.findComponent(GlTable).findAll('tr').at(trIdx).findAll('td').at(tdIdx);
  };

  beforeEach(() => {
    setWindowLocation('https://localhost');

    wrapper = createComponent();
  });

  describe('Empty behaviour', () => {
    it('should show the empty state if there is no data', async () => {
      wrapper.setProps({ events: [] });
      await nextTick();
      expect(wrapper.findComponent(EmptyResult).exists()).toBe(true);
    });
  });

  describe('Table behaviour', () => {
    it('should show', () => {
      expect(getCell(1, 0).text()).toBe('User');
    });

    it('applies a fixed table layout so long cell content cannot expand the table width', () => {
      expect(wrapper.findComponent(GlTable).find('table').classes()).toContain(
        'gl-table-layout-fixed',
      );
    });
  });

  describe('Pagination behaviour', () => {
    it('should show', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(true);
    });

    it('should hide if there is no data', async () => {
      wrapper.setProps({ events: [] });
      await nextTick();
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });

    it('should not have a previous page if the page is 1', () => {
      setWindowLocation('?page=1');
      wrapper = createComponent();

      expect(wrapper.findComponent(GlKeysetPagination).props().hasPreviousPage).toBe(false);
    });

    it('should have a previous page if the page is 2', () => {
      setWindowLocation('?page=2');
      wrapper = createComponent();

      expect(wrapper.findComponent(GlKeysetPagination).props().hasPreviousPage).toBe(true);
    });

    it('should not have a next page if isLastPage is true', async () => {
      wrapper.setProps({ isLastPage: true });
      await nextTick();
      expect(wrapper.findComponent(GlKeysetPagination).props().hasNextPage).toBe(false);
    });

    it('should have a next page if the page is 1', () => {
      setWindowLocation('?page=1');
      wrapper = createComponent();

      expect(wrapper.findComponent(GlKeysetPagination).props().hasNextPage).toBe(true);
    });

    describe('navigation', () => {
      it('should call visitUrl with correct page when prev is emitted', () => {
        setWindowLocation('?page=2');
        wrapper = createComponent();

        wrapper.findComponent(GlKeysetPagination).vm.$emit('prev');

        expect(visitUrl).toHaveBeenCalledWith('https://localhost/?page=1');
      });

      it('should call visitUrl with correct page when next is emitted', () => {
        setWindowLocation('?page=1');
        wrapper = createComponent();

        wrapper.findComponent(GlKeysetPagination).vm.$emit('next');

        expect(visitUrl).toHaveBeenCalledWith('https://localhost/?page=2');
      });
    });
  });
});
