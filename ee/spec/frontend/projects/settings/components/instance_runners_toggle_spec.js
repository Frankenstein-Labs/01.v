import { GlToggle, GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAxiosAdapter from 'axios-mock-adapter';
import IdentityVerificationRequiredAlert from 'ee_component/vue_shared/components/pipeline_account_verification_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_OK,
  HTTP_STATUS_UNAUTHORIZED,
} from '~/lib/utils/http_status';
import InstanceRunnersToggle from '~/projects/settings/components/instance_runners_toggle.vue';
import { IDENTITY_VERIFICATION_REQUIRED_ERROR } from '~/projects/settings/constants';

const TEST_UPDATE_PATH = '/test/update_shared_runners';

describe('projects/settings/components/shared_runners', () => {
  let wrapper;
  let mockAxios;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(InstanceRunnersToggle, {
      provide: {
        identityVerificationPath: '/-/identity_verification',
        identityVerificationRequired: true,
      },
      propsData: {
        isEnabled: false,
        isDisabledAndUnoverridable: false,
        isLoading: false,
        updatePath: TEST_UPDATE_PATH,
        ...props,
      },
      stubs: {
        IdentityVerificationRequiredAlert,
      },
    });
  };

  const findSharedRunnersToggle = () => wrapper.findComponent(GlToggle);
  const findIdentityVerificationRequiredAlert = () =>
    wrapper.findComponent(IdentityVerificationRequiredAlert);
  const findGenericAlert = () => wrapper.findComponent(GlAlert);
  const getToggleValue = () => findSharedRunnersToggle().props('value');
  const isToggleDisabled = () => findSharedRunnersToggle().props('disabled');

  beforeEach(() => {
    mockAxios = new MockAxiosAdapter(axios);
    mockAxios.onPost(TEST_UPDATE_PATH).reply(HTTP_STATUS_OK);

    createComponent({
      isEnabled: false,
    });
  });

  it('should show the toggle button', () => {
    expect(findSharedRunnersToggle().exists()).toBe(true);
    expect(getToggleValue()).toBe(false);
    expect(isToggleDisabled()).toBe(false);
  });

  describe('Identity Verification requirement', () => {
    describe('when user is not identity verified', () => {
      beforeEach(() => {
        mockAxios
          .onPost(TEST_UPDATE_PATH)
          .reply(HTTP_STATUS_UNAUTHORIZED, { error: IDENTITY_VERIFICATION_REQUIRED_ERROR });
      });

      it('should show identity verification required alert', async () => {
        findSharedRunnersToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(findIdentityVerificationRequiredAlert().exists()).toBe(true);
        expect(findIdentityVerificationRequiredAlert().props('title')).toBe(
          'Before you can use GitLab-hosted runners, we need to verify your account.',
        );
      });
    });

    describe('when user is identity verified', () => {
      it('should not show identity verification required alert after toggling on and off', async () => {
        findSharedRunnersToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(mockAxios.history.post[0].data).toBeUndefined();
        expect(mockAxios.history.post).toHaveLength(1);
        expect(findIdentityVerificationRequiredAlert().exists()).toBe(false);

        findSharedRunnersToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mockAxios.history.post[1].data).toBeUndefined();
        expect(mockAxios.history.post).toHaveLength(2);
        expect(findIdentityVerificationRequiredAlert().exists()).toBe(false);
      });
    });

    describe('when toggling fails for some other reason', () => {
      beforeEach(() => {
        mockAxios.onPost(TEST_UPDATE_PATH).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('should show a generic alert instead', async () => {
        findSharedRunnersToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(findIdentityVerificationRequiredAlert().exists()).toBe(false);
        expect(findGenericAlert().exists()).toBe(true);
        expect(findGenericAlert().text()).toBe(
          'An error occurred while updating the configuration.',
        );
      });
    });
  });
});
