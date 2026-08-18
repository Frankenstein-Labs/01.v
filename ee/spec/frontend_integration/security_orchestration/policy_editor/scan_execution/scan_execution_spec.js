import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  mergeUrlParams: jest.fn(),
}));

describe('Policy Editor', () => {
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

  const findSelectScanExecutionPolicyButton = () =>
    wrapper.findComponentByTestId('select-policy-scan_execution_policy');

  beforeEach(() => {
    createWrapper();
    findSelectScanExecutionPolicyButton().vm.$emit('click');
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('rendering', () => {
    it('redirects to editor page with correct type', () => {
      expect(urlUtils.mergeUrlParams).toHaveBeenCalledWith(
        { type: 'scan_execution_policy' },
        'http://test.host/',
      );
    });
  });
});
