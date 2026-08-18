import { GlToggle } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify } from '../utils';
import { mockSkipCiScanExecutionManifest } from './mocks';

describe('Skip ci for scan execution policy', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
    });
  };

  const findSkipCiSelectorToggle = () => wrapper.findComponent(GlToggle);
  const findSkipCiSelector = () => wrapper.findComponent(SkipCiSelector);

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('scan_execution_policy');
  });

  describe('allow skip ci', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('allows to skip ci configuration for scan execution', async () => {
      const verifyRuleMode = () => {
        expect(findSkipCiSelector().exists()).toBe(true);
      };

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual({
        allowed: true,
      });

      await findSkipCiSelectorToggle().vm.$emit('change', true);

      await verify({
        manifest: mockSkipCiScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
