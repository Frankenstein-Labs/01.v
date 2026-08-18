import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAvailabilityNamespaces from 'ee/ai/settings/components/duo_availability_namespaces.vue';
import DuoAvailabilityNamespacesFilter from 'ee/ai/settings/components/duo_availability_namespaces_filter.vue';
import DuoAvailabilityNamespacesTable from 'ee/ai/settings/components/duo_availability_namespaces_table.vue';

describe('DuoAvailabilityNamespaces', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DuoAvailabilityNamespaces, {});
  };

  const findToggleButton = () =>
    wrapper.findComponentByTestId('duo-availability-namespaces-expand-toggle');
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findFilter = () => wrapper.findComponent(DuoAvailabilityNamespacesFilter);
  const findTable = () => wrapper.findComponent(DuoAvailabilityNamespacesTable);

  beforeEach(() => {
    createComponent();
  });

  it('renders the section heading', () => {
    expect(wrapper.text()).toContain('Group Duo availability');
  });

  it('renders the section description', () => {
    expect(wrapper.text()).toContain(
      'Override the instance-wide GitLab Duo availability for individual groups. Changes cascade to subgroups unless overridden.',
    );
  });

  describe('collapsed by default', () => {
    it('renders the collapse as not visible', () => {
      expect(findCollapse().props('visible')).toBe(false);
    });

    it('shows the "Show groups" label', () => {
      expect(findToggleButton().text()).toBe('Show groups');
    });

    it('renders a right chevron icon', () => {
      expect(findToggleButton().props('icon')).toBe('chevron-right');
    });

    it('sets aria-expanded to false', () => {
      expect(findToggleButton().attributes('aria-expanded')).toBe('false');
    });

    it('sets aria-controls to the collapse id', () => {
      expect(findToggleButton().attributes('aria-controls')).toBe(findCollapse().attributes('id'));
    });

    it('passes enabled=false to the table', () => {
      expect(findTable().props('enabled')).toBe(false);
    });
  });

  describe('when the toggle button is clicked', () => {
    beforeEach(async () => {
      await findToggleButton().vm.$emit('click');
    });

    it('expands the collapse', () => {
      expect(findCollapse().props('visible')).toBe(true);
    });

    it('shows the "Hide groups" label', () => {
      expect(findToggleButton().text()).toBe('Hide groups');
    });

    it('renders a down chevron icon', () => {
      expect(findToggleButton().props('icon')).toBe('chevron-down');
    });

    it('sets aria-expanded to true', () => {
      expect(findToggleButton().attributes('aria-expanded')).toBe('true');
    });

    it('passes enabled=true to the table', () => {
      expect(findTable().props('enabled')).toBe(true);
    });

    it('collapses again when clicked a second time', async () => {
      await findToggleButton().vm.$emit('click');

      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('filtering', () => {
    it('passes the default admin-locked filter to the table', () => {
      expect(findTable().props('filter')).toEqual({ adminLocked: true });
    });

    it('updates the filter passed to the table when the filter component emits filter', async () => {
      await findFilter().vm.$emit('filter', { search: 'foo' });

      expect(findTable().props('filter')).toEqual({ search: 'foo' });
    });

    it('clears the filter passed to the table when the filter component emits an empty filter', async () => {
      await findFilter().vm.$emit('filter', { search: 'foo' });
      await findFilter().vm.$emit('filter', {});

      expect(findTable().props('filter')).toEqual({});
    });
  });
});
