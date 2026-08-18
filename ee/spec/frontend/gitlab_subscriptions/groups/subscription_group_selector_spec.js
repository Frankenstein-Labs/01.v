import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAccordion, GlAccordionItem, GlAlert, GlCollapsibleListbox, GlForm } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import Component from 'ee/gitlab_subscriptions/groups/new/components/subscription_group_selector.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import { getGroupPathAvailability } from '~/rest_api';
import { subscriptionsCreateGroup } from 'ee_else_ce/api/groups_api';
import namespacePurchaseEligibilityQuery from 'ee/gitlab_subscriptions/groups/new/graphql/namespace_purchase_eligibility.customer.query.graphql';

jest.mock('ee_else_ce/api/groups_api');
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
  isValidURL: jest.fn(() => true),
}));
jest.mock('~/rest_api', () => ({
  getGroupPathAvailability: jest.fn(),
}));

Vue.use(VueApollo);

describe('SubscriptionGroupSelector component', () => {
  let wrapper;

  const eligibleGroups = [
    { id: 1, name: 'Group one', fullPath: 'group-one' },
    { id: 2, name: 'Group two', fullPath: 'group-two' },
    { id: 3, name: 'Group three', fullPath: 'group-three' },
    { id: 4, name: 'Group four', fullPath: 'group-four' },
  ];

  const plansData = {
    code: 'premium',
    id: 'premium-plan-id',
    purchaseLink: { href: 'path/to/purchase?plan_id=premium-plan-id' },
  };

  const rootUrl = 'https://gitlab.com/';

  const defaultPropsData = { eligibleGroups, plansData, rootUrl };

  const groupNameErrorMessage = `can contain only letters, digits, emoji, '_', '.', dash, space, parenthesis. It must start with letter, digit, emoji or '_'`;
  const groupPathErrorMessage = `has already been taken`;

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAllGroupNames = () =>
    wrapper.findAllByTestId('group-name').wrappers.map((w) => w.text());
  const findAllGroupPaths = () =>
    wrapper.findAllByTestId('group-path').wrappers.map((w) => w.text());
  const findGroupNameInput = () => wrapper.findByTestId('subscription-group-name-input');
  const findCreateNewGroupButton = () =>
    wrapper.findComponentByTestId('show-new-group-form-button');
  const findContinueButton = () => wrapper.findComponentByTestId('continue-button');
  const findGroupUrl = () => wrapper.findByTestId('group-url');
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findHeader = () => wrapper.find('h2');
  const findGroupDescription = () => wrapper.findByTestId('group-description');
  const findGroupIdValidationMessage = () =>
    wrapper.findByText('Select a group for your subscription.');
  const findGroupNameValidationMessage = () =>
    wrapper.findByTestId('subscription-group-name-group').find('.invalid-feedback');
  const findEligibilityErrorAlert = () => wrapper.findComponentByTestId('eligibility-alert');
  const noGroupNameErrorMessage = 'Enter a descriptive name for your group.';
  const groupNameStartsWithInvalidCharactersErrorMessage =
    'Group name must start with a letter, digit, emoji, or underscore.';
  const groupNameContainsInvalidCharactersErrorMessage =
    'Group name can contain only letters, digits, dashes, spaces, dots, underscores, parenthesis, and emojis.';

  const showNewGroupForm = async () => {
    findCreateNewGroupButton().vm.$emit('click');
    await nextTick();
  };

  const changeGroupName = async (groupName) => {
    await findGroupNameInput().setValue(groupName);
    await nextTick();
  };

  const selectGroup = async (groupId) => {
    findCollapsibleListbox().vm.$emit('select', groupId);
    await nextTick();
  };

  const submitForm = async () => {
    wrapper.findComponent(GlForm).trigger('submit');
    await nextTick();
  };

  const mockAvailableGroupPathResponse = () => {
    getGroupPathAvailability.mockResolvedValueOnce({
      data: { exists: false, suggests: [] },
    });
  };

  const mockUnavailableGroupPathResponse = (urlSuggestions = []) => {
    getGroupPathAvailability.mockResolvedValueOnce({
      data: { exists: true, suggests: urlSuggestions },
    });
  };

  const mockUnsuccessfulGroupPathResponse = () => {
    getGroupPathAvailability.mockRejectedValueOnce({});
  };

  const mockEligibilityCheckResponse = (path = null, errors = []) => {
    return createMockApollo([
      [
        namespacePurchaseEligibilityQuery,
        jest.fn().mockResolvedValue({
          data: {
            namespacePurchaseEligibility: {
              path,
              errors,
            },
          },
        }),
      ],
    ]);
  };

  const mockEligibilityCheckError = () => {
    return createMockApollo([
      [namespacePurchaseEligibilityQuery, jest.fn().mockRejectedValue(new Error('API Error'))],
    ]);
  };

  const createComponent = (propsData = {}, apolloProvider = null) => {
    wrapper = mountExtended(Component, {
      attachTo: document.body,
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
      apolloProvider,
    });
  };

  describe('title', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders title correctly for premium plan', () => {
      expect(findHeader().text()).toBe(`Select a group for your Premium subscription`);
    });

    it('renders title correctly for ultimate plan', () => {
      createComponent({ plansData: { ...plansData, code: 'ultimate' } });

      expect(findHeader().text()).toBe(`Select a group for your Ultimate subscription`);
    });

    it('renders title correctly for other plans', () => {
      createComponent({ plansData: { ...plansData, code: 'non-premium', name: 'SaaS' } });

      expect(findHeader().text()).toBe(`Select a group for your SaaS subscription`);
    });
  });

  describe('group selection', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders collapsible list box with correct options', () => {
      const expectedResult = eligibleGroups.map(({ id, name, fullPath }) => ({
        value: id,
        text: name,
        secondaryText: `/${fullPath}`,
      }));

      expect(findCollapsibleListbox().props().items).toEqual(expectedResult);
    });

    it('renders group name and path', () => {
      expect(findAllGroupNames()).toEqual(eligibleGroups.map((group) => group.name));
      expect(findAllGroupPaths()).toEqual(eligibleGroups.map((group) => `/${group.fullPath}`));
    });

    it('renders collapsible list box with correct variant', () => {
      expect(findCollapsibleListbox().props('variant')).toBe('default');
    });

    it('does not show validation message on initial render', () => {
      expect(findGroupIdValidationMessage().exists()).toBe(false);
    });

    it('shows appropriate toggle text on initial render', () => {
      expect(findCollapsibleListbox().props().toggleText).toBe('Select a group');
    });

    it('does not show group name input on initial render', () => {
      expect(findGroupNameInput().exists()).toBe(false);
    });

    it('does not show group description', () => {
      expect(findGroupDescription().exists()).toBe(false);
    });

    it('shows validation message when no group is selected', async () => {
      await submitForm();

      expect(findGroupIdValidationMessage().exists()).toBe(true);
      expect(findCollapsibleListbox().props('variant')).toBe('danger');
    });

    it('does not redirect when no group is selected', async () => {
      await submitForm();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(findContinueButton().props('loading')).toBe(false);
    });

    it('shows appropriate toggle text when a group is selected', async () => {
      const selectedGroup = eligibleGroups[2];

      await selectGroup(selectedGroup.id);

      expect(findCollapsibleListbox().props().toggleText).toBe(selectedGroup.name);
    });

    it('redirects to purchase flow when a valid group is selected', async () => {
      const selectedGroupId = eligibleGroups[2].id;
      const expectedUrl = `${plansData.purchaseLink.href}&gl_namespace_id=${selectedGroupId}&ref_source=subscription_group_select_page`;

      await selectGroup(selectedGroupId);
      await submitForm();

      expect(visitUrl).toHaveBeenCalledWith(expectedUrl);
      expect(findContinueButton().props('loading')).toBe(false);
    });

    it('includes promo_code in purchase URL when provided', async () => {
      const promoCode = 'TESTPROMO';

      wrapper.destroy();
      createComponent({ promoCode });

      const selectedGroupId = eligibleGroups[2].id;
      const expectedUrl = `${plansData.purchaseLink.href}&gl_namespace_id=${selectedGroupId}&promo_code=${promoCode}&ref_source=subscription_group_select_page`;

      await selectGroup(selectedGroupId);
      await submitForm();

      expect(visitUrl).toHaveBeenCalledWith(expectedUrl);
      expect(findContinueButton().props('loading')).toBe(false);
    });

    it('does not call create group API when continuing with existing group', async () => {
      await selectGroup(eligibleGroups[2].id);
      await submitForm();

      expect(subscriptionsCreateGroup).not.toHaveBeenCalled();
    });
  });

  describe('when purchase link is missing', () => {
    it('reports an error when no purchase link URL is provided', async () => {
      const plansDataProp = { ...plansData, purchaseLink: null };
      const error = `Missing purchase link for plan ${JSON.stringify(plansDataProp)}`;

      createComponent({ plansData: plansDataProp });

      await selectGroup(eligibleGroups[2].id);
      await submitForm();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(findContinueButton().props('loading')).toBe(false);
      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { vue_component: 'SubscriptionGroupSelector' },
      });
    });
  });

  describe('new group creation', () => {
    describe('when choosing to create a new group', () => {
      let spy;

      beforeEach(async () => {
        createComponent();
        spy = jest.spyOn(wrapper.vm.$refs.collapsibleList, 'close');
        await showNewGroupForm();
      });

      it('shows group name input', () => {
        expect(findGroupNameInput().exists()).toBe(true);
      });

      it('shows appropriate toggle text', () => {
        expect(findCollapsibleListbox().props().toggleText).toBe('Create new group');
      });

      it('does not show validation message', () => {
        expect(findGroupNameValidationMessage().exists()).toBe(false);
      });

      it('shows default group URL', () => {
        expect(findGroupUrl().text()).toBe(`${rootUrl}{group}`);
      });

      it('closes the collapsible list box', () => {
        expect(spy).toHaveBeenCalled();
      });
    });

    describe('when choosing to create a new group after selecting an existing group', () => {
      beforeEach(async () => {
        createComponent();
        await selectGroup(eligibleGroups[2].id);
        await showNewGroupForm();
      });

      it('shows appropriate toggle text', () => {
        expect(findCollapsibleListbox().props().toggleText).toBe('Create new group');
      });

      it('shows group name input', () => {
        expect(findGroupNameInput().exists()).toBe(true);
      });
    });

    describe('when no group name is provided', () => {
      beforeEach(async () => {
        createComponent();
        await showNewGroupForm();
        await submitForm();
      });

      it('shows validation message', () => {
        expect(findGroupNameValidationMessage().text()).toBe(noGroupNameErrorMessage);
      });

      it('does not redirect', () => {
        expect(visitUrl).not.toHaveBeenCalled();
        expect(findContinueButton().props('loading')).toBe(false);
      });

      it('does not show validation message for group selection', () => {
        expect(findGroupIdValidationMessage().exists()).toBe(false);
      });
    });

    describe('group name validation', () => {
      beforeEach(async () => {
        createComponent();
        await showNewGroupForm();
      });

      it.each(['#test', '&test', '%test', '@test', '.test'])(
        'shows validation message when group name starts with an invalid character',
        async (groupName) => {
          await changeGroupName(groupName);

          await submitForm();

          expect(findGroupNameValidationMessage().text()).toBe(
            groupNameStartsWithInvalidCharactersErrorMessage,
          );
        },
      );

      it('shows validation message when group name contains an invalid character', async () => {
        await changeGroupName('test#!@$%^&*=+|[]{};"?,<>');

        await submitForm();

        expect(findGroupNameValidationMessage().text()).toBe(
          groupNameContainsInvalidCharactersErrorMessage,
        );
      });

      it.each(['test', '0test', '_test', '🤖test'])(
        'does not show a validation message when group name starts with a valid character',
        async (groupName) => {
          await changeGroupName(groupName);

          await submitForm();

          expect(findGroupNameValidationMessage().exists()).toBe(false);
        },
      );

      it.each(['test0-_. ()🤖test'])(
        'does not show a validation message when group name does not contain an invalid character',
        async (groupName) => {
          await changeGroupName(groupName);

          await submitForm();

          expect(findGroupNameValidationMessage().exists()).toBe(false);
        },
      );
    });

    describe('on group name input', () => {
      describe('when group path is available', () => {
        beforeEach(async () => {
          mockAvailableGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('calls group availability API', () => {
          expect(getGroupPathAvailability).toHaveBeenCalledWith('test-group', undefined, {
            signal: expect.any(AbortSignal),
          });
        });

        it('shows path where group will be created', () => {
          expect(findGroupUrl().text()).toBe(`${rootUrl}test-group`);
        });
      });

      describe('when group path is not available', () => {
        beforeEach(async () => {
          mockUnavailableGroupPathResponse(['unique-path']);
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('shows unique path where group will be created', () => {
          expect(findGroupUrl().text()).toBe(`${rootUrl}unique-path`);
        });
      });

      describe('when no path suggestions are available', () => {
        beforeEach(async () => {
          mockUnavailableGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('does not show an error message', () => {
          expect(findErrorAlert().exists()).toBe(false);
        });
      });

      describe('when path availability API call fails', () => {
        beforeEach(async () => {
          mockUnsuccessfulGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('does not show an error message', () => {
          expect(findErrorAlert().exists()).toBe(false);
        });
      });

      describe('when multiple API calls are in progress', () => {
        it('aborts the first API call and resolves the second API call', async () => {
          getGroupPathAvailability.mockRejectedValueOnce({ __CANCEL__: true });
          mockUnavailableGroupPathResponse(['test-group']);

          const abortSpy = jest.spyOn(AbortController.prototype, 'abort');

          createComponent();

          await showNewGroupForm();
          await changeGroupName('test');
          await changeGroupName('test group');

          expect(findErrorAlert().exists()).toBe(false);
          expect(findGroupUrl().text()).toBe(`${rootUrl}test-group`);
          expect(abortSpy).toHaveBeenCalled();
        });
      });
    });

    describe('when creating a new group', () => {
      beforeEach(async () => {
        mockUnavailableGroupPathResponse(['unique-path']);
        createComponent();
        await showNewGroupForm();
        await changeGroupName('test group');
      });
      describe('when group creation is successful', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockResolvedValueOnce({ data: { id: 123 } });

          await submitForm();
          await waitForPromises();
        });

        it('calls create group API with appropriate params', () => {
          expect(subscriptionsCreateGroup).toHaveBeenCalledWith({
            name: 'test group',
            path: 'unique-path',
          });
        });

        it('redirects to purchase page', () => {
          expect(visitUrl).toHaveBeenCalledWith(
            `${plansData.purchaseLink.href}&gl_namespace_id=123&ref_source=subscription_group_select_page`,
          );
          expect(findContinueButton().props('loading')).toBe(false);
        });
      });

      describe('when group creation is successful with promo code', () => {
        const promoCode = 'NEWPROMO';

        beforeEach(async () => {
          wrapper.destroy();

          mockUnavailableGroupPathResponse(['unique-path-promo']);
          createComponent({ promoCode });
          await showNewGroupForm();
          await changeGroupName('test group');

          subscriptionsCreateGroup.mockResolvedValueOnce({ data: { id: 456 } });

          await submitForm();
          await waitForPromises();
        });

        it('includes promo_code in purchase URL', () => {
          expect(visitUrl).toHaveBeenCalledWith(
            `${plansData.purchaseLink.href}&gl_namespace_id=456&promo_code=${promoCode}&ref_source=subscription_group_select_page`,
          );
          expect(findContinueButton().props('loading')).toBe(false);
        });
      });

      describe('when API response has no group id', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockResolvedValueOnce({ data: {} });

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
          expect(findContinueButton().props('loading')).toBe(false);
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            `An error occurred while creating the group. Please try again.`,
          );
        });
      });

      describe('when group name is invalid', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockRejectedValueOnce({
            response: {
              data: {
                errors: {
                  name: [groupNameErrorMessage],
                },
              },
            },
          });

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
          expect(findContinueButton().props('loading')).toBe(false);
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(`Group name ${groupNameErrorMessage}`);
        });
      });

      describe('when there is an error with path', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockRejectedValueOnce({
            response: {
              data: {
                errors: {
                  path: [groupPathErrorMessage],
                },
              },
            },
          });

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
          expect(findContinueButton().props('loading')).toBe(false);
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(`Group URL ${groupPathErrorMessage}`);
        });
      });

      describe('when group creation is unsuccessful', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockRejectedValueOnce(new Error('Error message'));

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
          expect(findContinueButton().props('loading')).toBe(false);
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            `An error occurred while creating the group. Please try again.`,
          );
        });
      });
    });
  });

  describe('when no eligible groups exist', () => {
    beforeEach(() => {
      createComponent({ eligibleGroups: [] });
    });

    it('shows group name input', () => {
      expect(findGroupNameInput().exists()).toBe(true);
    });

    it('does not show group selection input', () => {
      expect(findCollapsibleListbox().exists()).toBe(false);
    });

    it('does not show the accordion when no eligible groups exist', () => {
      expect(findAccordion().exists()).toBe(false);
    });

    it('shows group description', () => {
      expect(findGroupDescription().exists()).toBe(true);
    });
  });

  describe('accordion', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion', () => {
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('renders accordion item', () => {
      const accordionItem = findAccordionItem();

      expect(accordionItem.props('title')).toBe(`Why can't I find my group?`);
      expect(accordionItem.text()).toContain(
        `Your group will only be displayed in the list above if:`,
      );
      expect(accordionItem.text()).toContain(`You're assigned the Owner role of the group`);
      expect(accordionItem.text()).toContain(`The group is a top-level group on a Free tier`);
    });

    it('shows the GitLab Credits reason for base tier plans', () => {
      expect(findAccordionItem().text()).toContain(
        `The group does not have an active subscription with GitLab Credits`,
      );
    });

    it('does not show the GitLab Credits reason for non-base tier plans', () => {
      createComponent({ plansData: { ...plansData, code: 'storage' } });

      expect(findAccordionItem().text()).not.toContain(
        `The group does not have an active subscription with GitLab Credits`,
      );
    });
  });

  describe('eligibility alert visibility', () => {
    describe('when there are no eligibility errors', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not display the eligibility alert', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(false);
      });
    });

    describe('when eligibility errors are present', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(null, [
          {
            attribute: 'subscription_count',
            type: 'invalid',
            message: 'This group already has an active subscription',
          },
        ]);
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('displays the eligibility alert', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(true);
      });

      it('displays the alert with plan name in title', () => {
        const alert = findEligibilityErrorAlert();
        expect(alert.text()).toContain('This group is not eligible for Premium');
      });

      it('passes error to the alert component', () => {
        const alert = findEligibilityErrorAlert();
        expect(alert.props('error')).toBeDefined();
        expect(alert.props('planName')).toBe('Premium');
      });

      it('stops loading when eligibility error is set', () => {
        expect(findContinueButton().props('loading')).toBe(false);
      });
    });

    describe('when eligibility check returns no errors', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(null, []);
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('does not display the eligibility alert', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(false);
      });
    });

    describe('when eligibility check fails', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckError();
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('does not display the eligibility alert', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(false);
      });

      it('displays error message instead', () => {
        expect(findErrorAlert().text()).toContain(
          'An error occurred while checking eligibility. Please try again.',
        );
      });
    });

    describe('when eligibility check returns multiple errors', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(null, [
          {
            attribute: 'subscription_count',
            type: 'invalid',
            message: 'This group already has an active subscription',
          },
          {
            attribute: 'group_type',
            type: 'invalid',
            message: 'This group type is not eligible for this plan',
          },
        ]);
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('displays the eligibility alert', () => {
        const alert = findEligibilityErrorAlert();
        expect(alert.exists()).toBe(true);
      });

      it('displays error message in the alert', () => {
        const alert = findEligibilityErrorAlert();
        expect(alert.props('error').message).toContain(
          'This group already has an active subscription',
        );
        expect(alert.props('error').message).toContain(
          'This group type is not eligible for this plan',
        );
        expect(alert.props('planName')).toBe('Premium');
      });
    });

    describe('when eligibility check returns errors with promo code', () => {
      const promoCode = 'TESTPROMO';

      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(null, [
          {
            attribute: 'subscription_count',
            type: 'invalid',
            message: 'This group already has an active subscription',
          },
        ]);
        createComponent({ planType: 'gitlab_credits', promoCode }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('displays the eligibility alert even with promo code', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(true);
      });

      it('does not redirect to purchase flow', () => {
        expect(visitUrl).not.toHaveBeenCalled();
      });
    });

    describe('when eligibility errors are cleared by selecting a different group', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(null, [
          {
            attribute: 'subscription_count',
            type: 'invalid',
            message: 'This group already has an active subscription',
          },
        ]);
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('clears eligibility errors when a different group is selected', async () => {
        expect(findEligibilityErrorAlert().exists()).toBe(true);

        await selectGroup(eligibleGroups[1].id);

        expect(findEligibilityErrorAlert().exists()).toBe(false);
      });
    });

    describe('when eligibility check returns a purchase path', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits',
        );
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('calls navigateToPurchaseFlowWithPath with the API response path', () => {
        expect(visitUrl).toHaveBeenCalledWith(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits&plan_id=premium-plan-id',
        );
      });

      it('does not display the eligibility alert', () => {
        expect(findEligibilityErrorAlert().exists()).toBe(false);
      });
    });

    describe('when eligibility check returns a purchase path with promo code', () => {
      const promoCode = 'PROMO123';

      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits',
        );
        createComponent({ planType: 'gitlab_credits', promoCode }, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('includes promo code in the navigateToPurchaseFlowWithPath call', () => {
        expect(visitUrl).toHaveBeenCalledWith(
          `https://customers.gitlab.com/purchase?plan=gitlab_credits&plan_id=premium-plan-id&promo_code=${promoCode}`,
        );
      });
    });

    describe('when eligibility check returns a purchase path with existing query parameters', () => {
      beforeEach(async () => {
        const plansDataWithParams = {
          ...plansData,
          purchaseLink: { href: 'path/to/purchase?plan_id=premium-plan-id&entry_point=billing' },
        };
        const apolloProvider = mockEligibilityCheckResponse(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits',
        );
        createComponent(
          { plansData: plansDataWithParams, planType: 'gitlab_credits' },
          apolloProvider,
        );
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('forwards parameters from plansData.purchaseLink.href to the eligibility path', () => {
        expect(visitUrl).toHaveBeenCalledWith(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits&plan_id=premium-plan-id&entry_point=billing',
        );
      });
    });

    describe('when eligibility check returns a purchase path but purchase link is missing', () => {
      beforeEach(async () => {
        const plansDataWithoutLink = { ...plansData, purchaseLink: null };
        const apolloProvider = mockEligibilityCheckResponse(
          'https://customers.gitlab.com/purchase?plan=gitlab_credits',
        );
        createComponent(
          { plansData: plansDataWithoutLink, planType: 'gitlab_credits' },
          apolloProvider,
        );
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it('does not redirect to purchase flow', () => {
        expect(visitUrl).not.toHaveBeenCalled();
      });

      it('reports error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(
          expect.stringContaining('Missing purchase link for plan'),
          {
            tags: { vue_component: 'SubscriptionGroupSelector' },
          },
        );
      });

      it('stops loading', () => {
        expect(findContinueButton().props('loading')).toBe(false);
      });
    });
  });

  describe('namespace purchase eligibility check', () => {
    describe('when planType is not provided', () => {
      beforeEach(async () => {
        createComponent();
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
      });

      it('redirects to purchase flow using plansData.purchaseLink', () => {
        const expectedUrl = `${plansData.purchaseLink.href}&gl_namespace_id=${eligibleGroups[0].id}&ref_source=subscription_group_select_page`;
        expect(visitUrl).toHaveBeenCalledWith(expectedUrl);
      });
    });

    describe('when planType is provided and creating a new group', () => {
      beforeEach(async () => {
        const apolloProvider = mockEligibilityCheckResponse();
        createComponent({ planType: 'gitlab_credits' }, apolloProvider);
        await showNewGroupForm();
      });

      it('redirects using original flow for new group', async () => {
        mockUnavailableGroupPathResponse(['unique-path']);
        subscriptionsCreateGroup.mockResolvedValueOnce({ data: { id: 789 } });

        await changeGroupName('test group');
        await submitForm();
        await waitForPromises();

        expect(visitUrl).toHaveBeenCalledWith(
          `${plansData.purchaseLink.href}&gl_namespace_id=789&ref_source=subscription_group_select_page`,
        );
      });
    });

    describe.each([
      {
        args: { planType: 'gitlab_credits' },
        expected: { planType: 'gitlab_credits', tier: null },
      },
      {
        args: { planType: 'gitlab_credits', tier: 'premium' },
        expected: { planType: 'gitlab_credits', tier: 'premium' },
      },
    ])('with args: $args', ({ args, expected }) => {
      let queryMock;

      beforeEach(async () => {
        queryMock = jest.fn().mockResolvedValue({
          data: {
            namespacePurchaseEligibility: {
              path: null,
              errors: [],
            },
          },
        });
        const apolloProvider = createMockApollo([[namespacePurchaseEligibilityQuery, queryMock]]);
        createComponent(args, apolloProvider);
        await selectGroup(eligibleGroups[0].id);
        await submitForm();
        await waitForPromises();
      });

      it(`sends ${JSON.stringify(expected)} in the namespacePurchaseEligibilityQuery`, () => {
        expect(queryMock).toHaveBeenCalledWith({
          glNamespaceId: eligibleGroups[0].id,
          ...expected,
        });
      });
    });
  });
});
