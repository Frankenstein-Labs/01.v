import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import IntegrationSectionAmazonQ from 'ee/integrations/edit/components/sections/amazon_q.vue';
import AmazonQApp from 'ee/amazon_q_settings/components/app.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

Vue.use(PiniaVuePlugin);

const TEST_SUBMIT_URL = '/foo/submit/url';
const TEST_DISCONNECT_URL = '/foo/disconnect/url';
const TEST_AMAZON_Q_VALID_ROLE_ARN = 'arn:aws:iam::123456789012:role/valid-role';

describe('ee/integrations/edit/components/sections/amazon_q.vue', () => {
  let pinia;
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(IntegrationSectionAmazonQ, { pinia });
  };

  const findAmazonQApp = () => wrapper.findComponent(AmazonQApp);

  beforeEach(() => {
    pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      customState: {
        amazonQProps: {
          amazonQSubmitUrl: TEST_SUBMIT_URL,
          amazonQDisconnectUrl: TEST_DISCONNECT_URL,
          amazonQInstanceUid: 'instance-uid',
          amazonQAwsProviderUrl: 'https://provider.url',
          amazonQAwsAudience: 'audience',
          amazonQReady: true,
          amazonQAvailability: 'default_on',
          amazonQRoleArn: TEST_AMAZON_Q_VALID_ROLE_ARN,
        },
      },
    });
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render app.vue', () => {
      expect(findAmazonQApp().exists()).toBe(true);
      expect(findAmazonQApp().props()).toEqual({
        submitUrl: TEST_SUBMIT_URL,
        disconnectUrl: TEST_DISCONNECT_URL,
        amazonQSettings: {
          availability: 'default_on',
          ready: true,
          roleArn: TEST_AMAZON_Q_VALID_ROLE_ARN,
        },
        identityProviderPayload: {
          aws_audience: 'audience',
          aws_provider_url: 'https://provider.url',
          instance_uid: 'instance-uid',
        },
      });
    });
  });

  describe('when store doesnt have amazonQProps', () => {
    beforeEach(() => {
      pinia = createTestingPinia({ stubActions: false });
      const store = useIntegrationForm();
      Object.assign(store, { customState: {} });

      createWrapper();
    });

    it('does not render app.vue', () => {
      expect(findAmazonQApp().exists()).toBe(false);
    });
  });
});
