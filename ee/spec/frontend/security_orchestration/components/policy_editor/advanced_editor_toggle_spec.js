import { GlLink, GlToggle } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import * as urlUtils from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';

describe('AdvancedEditorToggle', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AdvancedEditorToggle, {
      propsData,
      provide: {
        policyEditorEnabled: false,
        ...provide,
      },
    });
  };

  const findLink = () => wrapper.findComponent(GlLink);
  const findToggle = () => wrapper.findComponent(GlToggle);

  describe('default rendering', () => {
    it('renders disabled toggle', () => {
      createComponent();

      expect(findToggle().exists()).toBe(true);
      expect(findToggle().props('label')).toBe('Enable advanced editor');
      expect(findToggle().props('value')).toBe(false);
      expect(findLink().exists()).toBe(false);
    });

    it('renders enabled toggle', () => {
      createComponent({
        provide: {
          policyEditorEnabled: true,
        },
      });

      expect(findToggle().props('label')).toBe('Enable standard editor');
      expect(findToggle().props('value')).toBe(true);
      expect(findLink().exists()).toBe(true);
      expect(findLink().text()).toBe('Give us feedback');
    });
  });

  describe('event handling', () => {
    const MOCKED_USER_PREFERENCES_URL = '/api/v4/user/preferences';
    const mockAxios = new MockAdapter(axios);

    beforeEach(() => {
      gon.api_version = 'v4';

      mockAxios
        .onPut(MOCKED_USER_PREFERENCES_URL, { policy_advanced_editor: true })
        .reply(HTTP_STATUS_OK, { policy_editor_enabled: true });
    });

    it('saves advanced editor settings', async () => {
      createComponent();
      jest.spyOn(urlUtils, 'refreshCurrentPage').mockImplementation(() => '');

      findToggle().vm.$emit('change', true);
      await waitForPromises();

      expect(urlUtils.refreshCurrentPage).toHaveBeenCalled();
    });
  });
});
