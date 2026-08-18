import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HealthCheckListProbe from 'ee/usage_quotas/code_suggestions/components/health_check_list_probe.vue';

import { MOCK_NETWORK_PROBES } from '../mock_data';

describe('Health Check List Probe', () => {
  let wrapper;

  const MOCK_SUCCESS_PROBE = MOCK_NETWORK_PROBES.success[0];
  const MOCK_ERROR_PROBE = MOCK_NETWORK_PROBES.error[0];

  const defaultProps = {
    probe: MOCK_SUCCESS_PROBE,
  };

  const findHealthCheckProbe = () => wrapper.findByTestId('health-check-probe');
  const findHealthCheckIcon = () => wrapper.findComponent(GlIcon);

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(HealthCheckListProbe, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('template', () => {
    describe.each`
      description        | probe                 | icon                                            | css
      ${'success probe'} | ${MOCK_SUCCESS_PROBE} | ${{ name: 'check-circle', variant: 'success' }} | ${'gl-text-feedback-success gl-bg-feedback-success'}
      ${'error probe'}   | ${MOCK_ERROR_PROBE}   | ${{ name: 'error', variant: 'danger' }}         | ${'gl-text-feedback-danger gl-bg-feedback-danger'}
    `('$description', ({ probe, icon, css }) => {
      beforeEach(() => {
        createComponent({ props: { probe } });
      });

      it(`renders probe icon as ${icon.name} and ${icon.variant}`, () => {
        expect(findHealthCheckIcon().props()).toStrictEqual(expect.objectContaining(icon));
      });

      it(`renders probe css as ${css}`, () => {
        const BASE_CSS = 'gl-my-3 gl-rounded-small gl-px-3 gl-py-2';
        expect(findHealthCheckProbe().classes().join(' ')).toBe(`${BASE_CSS} ${css}`);
      });

      it(`renders probe message as ${probe.message}`, () => {
        expect(wrapper.findByText(probe.message).exists()).toBe(true);
      });
    });
  });
});
