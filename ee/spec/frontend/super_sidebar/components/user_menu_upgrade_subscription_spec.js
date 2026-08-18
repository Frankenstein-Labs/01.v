import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { GlDisclosureDropdownGroup, GlFormInput, GlIcon, GlModal } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import UserMenuUpgradeSubscription from 'ee/super_sidebar/components/user_menu_upgrade_subscription.vue';
import { createAlert } from '~/alert';
import { PROMO_URL } from '~/constants';
import axios from '~/lib/utils/axios_utils';
import { visitUrl, visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { HTTP_STATUS_OK, HTTP_STATUS_UNPROCESSABLE_ENTITY } from '~/lib/utils/http_status';

jest.mock('~/alert');

jest.mock('~/helpers/help_page_helper', () => ({
  helpPagePath: jest.fn((path, options) => `/help/${path}${options.anchor}`),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn(),
  visitUrlWithAlerts: jest.fn(),
}));

describe('UserMenuUpgradeSubscription component', () => {
  let wrapper;
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    createAlert.mockClear();
  });

  afterEach(() => {
    mock.restore();
  });

  const createWrapper = (upgradeLink = {}) => {
    wrapper = mountExtended(UserMenuUpgradeSubscription, {
      propsData: {
        upgradeLink,
      },
    });
  };

  const findUpgradeSubscriptionGroup = () => wrapper.findComponent(GlDisclosureDropdownGroup);
  const findUpgradeSubscriptionItem = () =>
    wrapper.findComponentByTestId('upgrade-subscription-item');
  const findConfirmModal = () => wrapper.findComponent(GlModal);
  const findConfirmInput = () => wrapper.findComponent(GlFormInput);

  describe('when upgrade subscription is available', () => {
    beforeEach(() => {
      createWrapper({ url: '/groups/test-group/-/billings', text: 'Upgrade subscription' });
    });

    it('renders the upgrade subscription group', () => {
      expect(findUpgradeSubscriptionGroup().exists()).toBe(true);
    });

    it('renders the upgrade subscription menu item', () => {
      expect(findUpgradeSubscriptionItem().exists()).toBe(true);
    });

    it('should render a link to upgrade subscription with correct URL', () => {
      expect(findUpgradeSubscriptionItem().text()).toBe('Upgrade subscription');
    });

    it('has Snowplow tracking attributes', () => {
      expect(findUpgradeSubscriptionItem().find('button').attributes()).toMatchObject({
        'data-track-property': 'nav_user_menu',
        'data-track-action': 'click_link',
        'data-track-label': 'upgrade_subscription',
      });
    });

    it('renders with license icon', () => {
      const icon = findUpgradeSubscriptionItem().findComponent(GlIcon);

      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('license');
    });

    it('renders with hotspot styling', () => {
      const hotspotElement = findUpgradeSubscriptionItem().find('.hotspot-pulse');

      expect(hotspotElement.exists()).toBe(true);
    });

    it('does not render the confirmation modal', () => {
      expect(findConfirmModal().exists()).toBe(false);
    });

    describe('onClick', () => {
      it('calls visitUrl with the upgrade link URL', () => {
        findUpgradeSubscriptionItem().vm.$emit('action');

        expect(visitUrl).toHaveBeenCalledWith('/groups/test-group/-/billings');
      });

      describe('when personal project', () => {
        const upgradeLink = {
          url: '/user_namespace/test-project/-/transfer_personal',
          text: 'Upgrade subscription',
          is_personal_project: true,
          project_name: 'test-project',
          project_full_path: 'user_namespace/test-project',
        };

        beforeEach(() => {
          wrapper = mountExtended(UserMenuUpgradeSubscription, {
            propsData: { upgradeLink },
            stubs: { GlModal: stubComponent(GlModal) },
          });
        });

        it('shows confirmation modal on click', async () => {
          expect(findConfirmModal().props('visible')).toBe(false);

          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          expect(findConfirmModal().props('visible')).toBe(true);
          expect(findConfirmModal().props('title')).toBe('Confirm group assignment');
        });

        it('disables confirm button when phrase does not match', async () => {
          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          expect(findConfirmModal().props('actionPrimary').attributes.disabled).toBe(true);
        });

        it('renders the confirmation phrase as the input label', async () => {
          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          expect(
            wrapper
              .findByLabelText(`Enter the following to confirm: ${upgradeLink.project_full_path}`)
              .attributes('autocomplete'),
          ).toBe('off');
        });

        it('enables confirm button when phrase matches', async () => {
          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          await findConfirmInput().setValue(upgradeLink.project_full_path);

          expect(findConfirmModal().props('actionPrimary').attributes.disabled).toBe(false);
        });

        it('resets confirmation phrase when modal is opened', async () => {
          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          await findConfirmInput().setValue('leftover-text');

          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          expect(findConfirmInput().element.value).toBe('');
        });

        it('does not transfer when modal is dismissed', async () => {
          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          findConfirmModal().vm.$emit('change', false);
          await waitForPromises();

          expect(visitUrlWithAlerts).not.toHaveBeenCalled();
        });

        it('makes a PUT request and redirects with success alert when confirmed', async () => {
          const redirectUrl = '/groups/new-test-group/-/billings';
          const groupName = 'new-test-group';

          mock
            .onPut(upgradeLink.url)
            .reply(HTTP_STATUS_OK, { redirect_to: redirectUrl, group_name: groupName });

          findUpgradeSubscriptionItem().vm.$emit('action');
          await nextTick();

          await findConfirmInput().setValue(upgradeLink.project_full_path);

          findConfirmModal().vm.$emit('primary');
          await waitForPromises();

          expect(visitUrlWithAlerts).toHaveBeenCalledWith(redirectUrl, [
            {
              id: 'transfer-personal-project-success',
              message: `Your personal project was assigned to ${groupName} for billing.`,
              variant: 'success',
            },
          ]);
        });

        describe('when the api responds with an error', () => {
          it('creates an alert', async () => {
            mock.onPut(upgradeLink.url).reply(HTTP_STATUS_UNPROCESSABLE_ENTITY);

            findUpgradeSubscriptionItem().vm.$emit('action');
            await nextTick();

            await findConfirmInput().setValue(upgradeLink.project_full_path);

            findConfirmModal().vm.$emit('primary');
            await waitForPromises();

            expect(createAlert).toHaveBeenCalledWith({
              title: 'Billing page is not available',
              message: expect.stringContaining(
                'An error occurred while assigning your project to a group for billing.',
              ),
              messageLinks: { link: { href: `${PROMO_URL}/pricing`, target: '_blank' } },
              primaryButton: expect.any(Object),
            });
          });
        });
      });
    });
  });
});
