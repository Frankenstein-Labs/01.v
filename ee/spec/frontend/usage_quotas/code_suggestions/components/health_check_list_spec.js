import { GlCollapse, GlLoadingIcon, GlAnimatedChevronRightDownIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import HealthCheckListCategory from 'ee/usage_quotas/code_suggestions/components/health_check_list_category.vue';
import HealthCheckListLoader from 'ee/usage_quotas/code_suggestions/components/health_check_list_loader.vue';
import getCloudConnectorHealthStatus from 'ee/usage_quotas/add_on/graphql/cloud_connector_health_check.query.graphql';
import { probesByCategory } from 'ee/usage_quotas/code_suggestions/utils';
import { parseBoolean } from '~/lib/utils/common_utils';

import {
  MOCK_NETWORK_PROBES,
  MOCK_SYNCHRONIZATION_PROBES,
  MOCK_SYSTEM_EXCHANGE_PROBES,
  MOCK_DUO_AGENT_PLATFORM_PROBES,
} from '../mock_data';

const success = {
  data: {
    cloudConnectorStatus: {
      success: true,
      probeResults: [
        ...MOCK_NETWORK_PROBES.success,
        ...MOCK_SYNCHRONIZATION_PROBES.success,
        ...MOCK_DUO_AGENT_PLATFORM_PROBES.success,
        ...MOCK_SYSTEM_EXCHANGE_PROBES.success,
      ],
    },
  },
};

const partialFailure = {
  data: {
    cloudConnectorStatus: {
      success: false,
      probeResults: [
        ...MOCK_NETWORK_PROBES.success,
        ...MOCK_SYNCHRONIZATION_PROBES.error,
        ...MOCK_DUO_AGENT_PLATFORM_PROBES.error,
        ...MOCK_SYSTEM_EXCHANGE_PROBES.error,
      ],
    },
  },
};

const totalFailure = {
  data: {
    cloudConnectorStatus: {
      success: false,
      probeResults: [
        ...MOCK_NETWORK_PROBES.error,
        ...MOCK_SYNCHRONIZATION_PROBES.error,
        ...MOCK_DUO_AGENT_PLATFORM_PROBES.error,
        ...MOCK_SYSTEM_EXCHANGE_PROBES.error,
      ],
    },
  },
};

Vue.use(VueApollo);

describe('HealthCheckList', () => {
  let wrapper;
  let mockApollo;
  let healthStatusReq;

  const findGlCollapse = () => wrapper.findComponent(GlCollapse);
  const findHealthCheckIcon = () => wrapper.findComponentByTestId('health-check-icon');
  const findHealthCheckTitle = () => wrapper.findByTestId('health-check-title');
  const findRunHealthCheckButton = () => wrapper.findComponentByTestId('run-health-check-button');
  const findHealthCheckExpandButton = () =>
    wrapper.findComponentByTestId('health-check-expand-button');
  const findHealthCheckExpandIcon = () => wrapper.findComponent(GlAnimatedChevronRightDownIcon);
  const findHealthCheckExpandText = () => wrapper.findByTestId('health-check-expand-text');
  const findHealthCheckFooterLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findHealthCheckFooterText = () => wrapper.findByTestId('health-check-footer-text');
  const findHealthCheckListLoader = () => wrapper.findComponent(HealthCheckListLoader);
  const findHealthCheckResults = () => wrapper.findByTestId('health-check-results');
  const findAllHealthCheckProbeCategories = () =>
    wrapper.findAllComponents(HealthCheckListCategory);

  const createComponent = ({ response = success } = {}) => {
    healthStatusReq = jest.fn().mockResolvedValue(response);
    mockApollo = createMockApollo([[getCloudConnectorHealthStatus, healthStatusReq]]);

    wrapper = shallowMountExtended(HealthCheckList, {
      apolloProvider: mockApollo,
    });
  };

  afterEach(() => {
    mockApollo = null;
    healthStatusReq = null;
  });

  describe('when collapse is not expanded', () => {
    describe('default', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders with the collapse not expanded', () => {
        expect(findGlCollapse().props('visible')).toBe(false);
      });

      it('renders expand button as collapsed', () => {
        // Vue compat doesn't know about component props if it extends other component
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(false);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Show results');
      });
    });

    describe('loading state', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders health check icon as status-health', () => {
        expect(findHealthCheckIcon().props('name')).toBe('status-health');
      });

      it('renders health check title as Updating…', () => {
        expect(findHealthCheckTitle().text()).toBe('Updating…');
      });

      it('disables run health check button', () => {
        expect(findRunHealthCheckButton().attributes().disabled).toBe('true');
        expect(findRunHealthCheckButton().props('loading')).toBe(true);
      });

      it('renders expand button text as Tests are running', () => {
        expect(findHealthCheckExpandText().text()).toBe('Tests are running');
      });
    });

    describe.each`
      description                | response          | icon                     | title                             | expandText
      ${'success state'}         | ${success}        | ${'check-circle-filled'} | ${'No health problems detected'}  | ${'GitLab Duo should be operational.'}
      ${'partial failure state'} | ${partialFailure} | ${'error'}               | ${'Problems detected with setup'} | ${'Not operational. Resolve issues to use GitLab Duo.'}
      ${'total failure state'}   | ${totalFailure}   | ${'error'}               | ${'Problems detected with setup'} | ${'Not operational. Resolve issues to use GitLab Duo.'}
    `('$description', ({ response, icon, title, expandText }) => {
      beforeEach(async () => {
        createComponent({ response });
        await waitForPromises();
      });

      it(`renders health check icon as ${icon}`, () => {
        expect(findHealthCheckIcon().props('name')).toBe(icon);
      });

      it(`renders health check title as ${title}`, () => {
        expect(findHealthCheckTitle().text()).toBe(title);
      });

      it(`renders expand button text as ${expandText}`, () => {
        expect(findHealthCheckExpandText().text()).toBe(expandText);
      });

      it('does not disable run health check button', () => {
        expect(findRunHealthCheckButton().attributes().disabled).toBeUndefined();
        expect(findRunHealthCheckButton().props('loading')).toBe(false);
      });
    });
  });

  describe('when collapse is expanded', () => {
    describe('default', () => {
      beforeEach(() => {
        createComponent();
        findHealthCheckExpandButton().vm.$emit('click');
      });

      it('renders with the collapse as expanded', () => {
        expect(findGlCollapse().props('visible')).toBe(true);
      });

      it('renders expand button as expanded', () => {
        // Vue compat doesn't know about component props if it extends other component
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(true);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Hide results');
      });
    });

    describe('loading state', () => {
      beforeEach(() => {
        createComponent();
        findHealthCheckExpandButton().vm.$emit('click');
      });

      it('renders health check icon as status-health', () => {
        expect(findHealthCheckIcon().props('name')).toBe('status-health');
      });

      it('renders health check title as Updating…', () => {
        expect(findHealthCheckTitle().text()).toBe('Updating…');
      });

      it('disables run health check button', () => {
        expect(findRunHealthCheckButton().attributes().disabled).toBe('true');
        expect(findRunHealthCheckButton().props('loading')).toBe(true);
      });

      it('renders expand button text as Tests are running', () => {
        expect(findHealthCheckExpandText().text()).toBe('Tests are running');
      });

      it('renders health check list loader', () => {
        expect(findHealthCheckListLoader().exists()).toBe(true);
        expect(findHealthCheckResults().exists()).toBe(false);
      });

      it('render the footer as a loading icon', () => {
        expect(findHealthCheckFooterLoader().exists()).toBe(true);
        expect(findHealthCheckFooterText().exists()).toBe(false);
      });
    });

    describe.each`
      description                | response          | icon                     | title                             | expandText        | footerText
      ${'success state'}         | ${success}        | ${'check-circle-filled'} | ${'No health problems detected'}  | ${'Hide results'} | ${'GitLab Duo should be operational.'}
      ${'partial failure state'} | ${partialFailure} | ${'error'}               | ${'Problems detected with setup'} | ${'Hide results'} | ${'Not operational. Resolve issues to use GitLab Duo.'}
      ${'total failure state'}   | ${totalFailure}   | ${'error'}               | ${'Problems detected with setup'} | ${'Hide results'} | ${'Not operational. Resolve issues to use GitLab Duo.'}
    `('$description', ({ response, icon, title, expandText, footerText }) => {
      beforeEach(async () => {
        createComponent({ response });
        findHealthCheckExpandButton().vm.$emit('click');
        await waitForPromises();
      });

      it(`renders health check icon as ${icon}`, () => {
        expect(findHealthCheckIcon().props('name')).toBe(icon);
      });

      it(`renders health check title as ${title}`, () => {
        expect(findHealthCheckTitle().text()).toBe(title);
      });

      it(`renders expand button text as ${expandText}`, () => {
        expect(findHealthCheckExpandText().text()).toBe(expandText);
      });

      it('does not disable run health check button', () => {
        expect(findRunHealthCheckButton().attributes().disabled).toBeUndefined();
        expect(findRunHealthCheckButton().props('loading')).toBe(false);
      });

      it('renders health check results', () => {
        expect(findHealthCheckListLoader().exists()).toBe(false);
        expect(findHealthCheckResults().exists()).toBe(true);
      });

      it(`render the footer as a ${footerText}`, () => {
        expect(findHealthCheckFooterLoader().exists()).toBe(false);
        expect(findHealthCheckFooterText().text()).toBe(footerText);
      });
    });
  });

  describe('health check categories', () => {
    const { probeResults } = success.data.cloudConnectorStatus;
    const categories = probesByCategory(probeResults);

    beforeEach(async () => {
      createComponent({ response: success });
      findHealthCheckExpandButton().vm.$emit('click');
      await waitForPromises();
    });

    it('renders each health check category', () => {
      expect(
        findAllHealthCheckProbeCategories().wrappers.map((w) => w.props('category')),
      ).toStrictEqual(categories);
    });
  });

  describe('onMount', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches health check immediately', () => {
      expect(healthStatusReq).toHaveBeenCalled();
    });

    it('renders with the collapse not expanded', () => {
      expect(findGlCollapse().props('visible')).toBe(false);
    });
  });

  describe('onExpandToggle', () => {
    describe('when collapse is not expanded', () => {
      beforeEach(() => {
        createComponent();
      });

      it('properly expands collapse after click', async () => {
        expect(findGlCollapse().props('visible')).toBe(false);
        // Vue compat doesn't know about component props if it extends other component
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(false);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Show results');

        findHealthCheckExpandButton().vm.$emit('click');
        await nextTick();

        expect(findGlCollapse().props('visible')).toBe(true);
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(true);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Hide results');
      });
    });

    describe('when collapse is expanded', () => {
      beforeEach(() => {
        createComponent();
        findHealthCheckExpandButton().vm.$emit('click');
      });

      it('properly collapses collapse after click', async () => {
        expect(findGlCollapse().props('visible')).toBe(true);
        // Vue compat doesn't know about component props if it extends other component
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(true);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Hide results');

        findHealthCheckExpandButton().vm.$emit('click');
        await nextTick();

        expect(findGlCollapse().props('visible')).toBe(false);
        expect(
          findHealthCheckExpandIcon().props('isOn') ??
            parseBoolean(findHealthCheckExpandIcon().attributes('is-on')),
        ).toBe(false);
        expect(findHealthCheckExpandButton().attributes('aria-label')).toBe('Show results');
      });
    });
  });

  describe('onRunHealthCheck', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();

      healthStatusReq.mockClear();
    });

    it('when button clicked, API is called and loading state is set', async () => {
      expect(findHealthCheckTitle().text()).toBe('No health problems detected');
      expect(healthStatusReq).not.toHaveBeenCalled();

      findRunHealthCheckButton().vm.$emit('click');
      await nextTick();

      expect(findHealthCheckTitle().text()).toBe('Updating…');
      expect(healthStatusReq).toHaveBeenCalledTimes(1);
    });
  });

  describe('downloadReport', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('renders the download button and is enabled when not loading', () => {
      const button = wrapper.findByTestId('download-report-button');

      expect(button.exists()).toBe(true); // Check if the button is present
      expect(button.attributes().disabled).toBeUndefined(); // Button should be enabled
    });

    it('disables the download button when loading', async () => {
      // Simulate running the health check, which should set isLoading to true
      findRunHealthCheckButton().vm.$emit('click');
      await nextTick(); // Ensure reactivity updates the DOM

      const button = wrapper.findByTestId('download-report-button');

      expect(button.exists()).toBe(true); // Check if the button is present
      expect(button.attributes().disabled).toBe('true'); // Button should be disabled with value "true"
    });
  });
});
