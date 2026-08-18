import { GlAlert, GlSprintf } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import MinimalAccessProvisioningAlert from 'ee/block_seat_overages/components/minimal_access_provisioning_alert.vue';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_UNAUTHORIZED } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

describe('MinimalAccessProvisioningAlert', () => {
  let wrapper;
  let mockAxios;

  const defaultProps = {
    dismissPath: '/example/dismiss-path',
    affectedUsersCount: 3,
    purchaseSeatsLink: 'https://example.com/purchase',
    learnMoreLink: 'https://example.com/learn-more',
    restrictedAccessLink: 'https://example.com/restricted-access',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(MinimalAccessProvisioningAlert, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlAlert: stubComponent(GlAlert, {
          template: '<div><slot></slot><slot name="actions"></slot></div>',
        }),
        GlSprintf: stubComponent(GlSprintf, {
          template: '<span><slot name="link" :content="\'restricted access\'"></slot></span>',
        }),
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSprintf = () => wrapper.findComponent(GlSprintf);
  const findRestrictedAccessLink = () => wrapper.findByTestId('restricted-access-link');
  const findPurchaseSeatsButton = () => wrapper.findComponentByTestId('purchase-seats-button');
  const findLearnMoreButton = () => wrapper.findByTestId('learn-more-button');

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('title', () => {
    it('uses the plural form when more than one user is affected', () => {
      createComponent({ affectedUsersCount: 3 });

      expect(findAlert().props('title')).toBe('3 users assigned the Minimal Access role');
    });

    it('uses the singular form when one user is affected', () => {
      createComponent({ affectedUsersCount: 1 });

      expect(findAlert().props('title')).toBe('1 user assigned the Minimal Access role');
    });
  });

  describe('body text', () => {
    it('uses the plural form when more than one user is affected', () => {
      createComponent({ affectedUsersCount: 3 });

      expect(findSprintf().props('message')).toContain(
        '%{count} users provisioned through LDAP or SAML/SCIM have been assigned the Minimal Access role',
      );
    });

    it('uses the singular form when one user is affected', () => {
      createComponent({ affectedUsersCount: 1 });

      expect(findSprintf().props('message')).toContain(
        '%{count} user provisioned through LDAP or SAML/SCIM has been assigned the Minimal Access role',
      );
    });
  });

  describe('links and actions', () => {
    beforeEach(() => createComponent());

    it('renders the restricted access link with the correct href', () => {
      expect(findRestrictedAccessLink().attributes('href')).toBe(defaultProps.restrictedAccessLink);
    });

    it('renders a Purchase more seats button linking to the purchase URL', () => {
      const button = findPurchaseSeatsButton();

      expect(button.text()).toBe('Purchase more seats');
      expect(button.attributes('href')).toBe(defaultProps.purchaseSeatsLink);
      expect(button.props('variant')).toBe('confirm');
    });

    it('renders a Learn more button linking to the docs URL', () => {
      const button = findLearnMoreButton();

      expect(button.text()).toBe('Learn more');
      expect(button.attributes('href')).toBe(defaultProps.learnMoreLink);
    });
  });

  describe('dismissal', () => {
    it('hides the alert immediately on dismiss', async () => {
      mockAxios.onPost(defaultProps.dismissPath).reply(HTTP_STATUS_OK);
      createComponent();

      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });

    it('posts to the dismiss path', async () => {
      mockAxios.onPost(defaultProps.dismissPath).reply(HTTP_STATUS_OK);
      createComponent();

      findAlert().vm.$emit('dismiss');
      await waitForPromises();

      expect(mockAxios.history.post).toHaveLength(1);
      expect(mockAxios.history.post[0].url).toBe(defaultProps.dismissPath);
    });

    it('reports the error to Sentry when the dismiss request fails', async () => {
      jest.spyOn(Sentry, 'captureException').mockImplementation();
      mockAxios.onPost(defaultProps.dismissPath).reply(HTTP_STATUS_UNAUTHORIZED);
      createComponent();

      findAlert().vm.$emit('dismiss');
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
