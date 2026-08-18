import { mountExtended } from 'helpers/vue_test_utils_helper';
import ComponentHealthCard from 'ee/orbit/components/component_health_card.vue';

describe('ComponentHealthCard', () => {
  let wrapper;

  const createComponent = (component) => {
    wrapper = mountExtended(ComponentHealthCard, {
      propsData: { component },
    });
  };

  const findHealthyDot = () => wrapper.findByTestId('healthy-dot');
  const findWarningIcon = () => wrapper.findComponentByTestId('unhealthy-warning-icon');
  const findMigratingIcon = () => wrapper.findByTestId('migrating-icon');

  describe('when component is healthy', () => {
    beforeEach(() => {
      createComponent({ name: 'clickhouse', status: 'healthy' });
    });

    it('renders the friendly component name', () => {
      expect(wrapper.text()).toContain('ClickHouse');
    });

    it('renders the healthy dot indicator', () => {
      expect(findHealthyDot().exists()).toBe(true);
      expect(findHealthyDot().classes()).toContain('gl-bg-status-success');
    });

    it('renders neither a warning nor a migrating indicator', () => {
      expect(findWarningIcon().exists()).toBe(false);
      expect(findMigratingIcon().exists()).toBe(false);
    });
  });

  describe('when component is migrating', () => {
    beforeEach(() => {
      createComponent({ name: 'schema_migration', status: 'migrating' });
    });

    it('renders the migrating indicator with an in-progress label', () => {
      expect(findMigratingIcon().exists()).toBe(true);
      expect(wrapper.text()).toContain('In progress');
    });

    it('renders neither the healthy dot nor a warning icon', () => {
      expect(findHealthyDot().exists()).toBe(false);
      expect(findWarningIcon().exists()).toBe(false);
    });

    it('renders the friendly component name', () => {
      expect(wrapper.text()).toContain('Schema migration');
    });
  });

  describe.each([
    ['unknown', { name: 'indexer', status: 'unknown' }],
    ['unhealthy', { name: 'indexer', status: 'unhealthy' }],
  ])('when component is %s', (_, component) => {
    beforeEach(() => {
      createComponent(component);
    });

    it('renders the warning icon with danger variant', () => {
      expect(findWarningIcon().exists()).toBe(true);
      expect(findWarningIcon().props('variant')).toBe('danger');
    });

    it('does not render the healthy dot', () => {
      expect(findHealthyDot().exists()).toBe(false);
    });
  });

  describe('display name', () => {
    it('humanizes an unmapped component name', () => {
      createComponent({ name: 'some_new_service', status: 'healthy' });

      expect(wrapper.text()).toContain('Some new service');
    });
  });

  describe('metadata', () => {
    describe('when metadata is present', () => {
      beforeEach(() => {
        createComponent({ name: 'clickhouse', status: 'healthy', metadata: { key: 'value' } });
      });

      it('renders the metadata hint', () => {
        expect(wrapper.text()).toContain('Additional metadata');
      });
    });

    describe('when metadata is absent', () => {
      beforeEach(() => {
        createComponent({ name: 'clickhouse', status: 'healthy' });
      });

      it('does not render the metadata hint', () => {
        expect(wrapper.text()).not.toContain('Additional metadata');
      });
    });
  });
});
