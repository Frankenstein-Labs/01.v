import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
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
      stubs: {
        SettingPopover: true,
      },
    });
  };

  const findSelectScanResultPolicyButton = () =>
    wrapper.findComponentByTestId('select-policy-approval_policy');

  beforeEach(() => {
    createWrapper();
    findSelectScanResultPolicyButton().vm.$emit('click');
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('rendering', () => {
    it('renders the page correctly', () => {
      expect(urlUtils.mergeUrlParams).toHaveBeenCalledWith(
        { type: 'approval_policy' },
        'http://test.host/',
      );
    });
  });
});
