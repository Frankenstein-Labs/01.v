import { shallowMountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import EnvironmentBreakdown from 'ee/cd/components/environment_breakdown.vue';
import { makeEnvironment } from './mock_data';

describe('EnvironmentBreakdown', () => {
  let wrapper;

  const findBreakdown = () => wrapper.findByTestId('environment-breakdown');
  const findTierGroup = (tier) => wrapper.findByTestId(`tier-group-${tier}`);
  const findAllTierHeadings = () => wrapper.findAllByTestId('tier-heading');
  const findEnvRow = (name) => extendedWrapper(wrapper.findByTestId(`env-row-${name}`));

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(EnvironmentBreakdown, {
      propsData: {
        environments: [makeEnvironment()],
        ...props,
      },
    });
  };

  describe('tier grouping and ordering', () => {
    it('groups environments by tier in promotion order', () => {
      createComponent({
        environments: [
          makeEnvironment({ id: '1', name: 'prod-1', tier: 'PRODUCTION' }),
          makeEnvironment({ id: '2', name: 'dev-1', tier: 'DEVELOPMENT' }),
          makeEnvironment({ id: '3', name: 'qa-1', tier: 'QA' }),
        ],
      });

      const headings = findAllTierHeadings();

      expect(headings).toHaveLength(3);
      expect(headings.at(0).text()).toBe('Development');
      expect(headings.at(1).text()).toBe('QA');
      expect(headings.at(2).text()).toBe('Production');
    });

    it('renders unknown tiers after known ones, using the raw tier name', () => {
      createComponent({
        environments: [
          makeEnvironment({ id: '1', name: 'custom-1', tier: 'CUSTOM' }),
          makeEnvironment({ id: '2', name: 'dev-1', tier: 'DEVELOPMENT' }),
        ],
      });

      const headings = findAllTierHeadings();

      expect(headings.at(0).text()).toBe('Development');
      expect(headings.at(1).text()).toBe('CUSTOM');
    });

    it('groups environments with no tier under UNKNOWN', () => {
      createComponent({ environments: [makeEnvironment({ name: 'untiered-1', tier: null })] });

      expect(findTierGroup('UNKNOWN').exists()).toBe(true);
      expect(findEnvRow('untiered-1').exists()).toBe(true);
    });
  });

  describe('environment row', () => {
    beforeEach(() => {
      createComponent({
        environments: [makeEnvironment({ name: 'web-1', version: 'v2.0.0', health: 'DEGRADED' })],
      });
    });

    it('renders the environment name', () => {
      expect(findEnvRow('web-1').findByTestId('env-name').text()).toBe('web-1');
    });

    it('renders the version in monospace', () => {
      const version = findEnvRow('web-1').findByTestId('env-version');

      expect(version.text()).toBe('v2.0.0');
      expect(version.classes()).toContain('gl-font-monospace');
    });

    it('renders the health badge with the mapped label and variant', () => {
      const badge = findEnvRow('web-1').findByTestId('env-health-badge');

      expect(badge.text()).toBe('Degraded');
      expect(badge.attributes('variant')).toBe('warning');
    });
  });

  describe('when an environment has no version', () => {
    beforeEach(() => {
      createComponent({ environments: [makeEnvironment({ name: 'web-1', version: null })] });
    });

    it('omits the version', () => {
      expect(findEnvRow('web-1').findByTestId('env-version').exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    it('does not render when environments is empty', () => {
      createComponent({ environments: [] });

      expect(findBreakdown().exists()).toBe(false);
    });
  });
});
