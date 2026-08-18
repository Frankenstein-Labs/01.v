import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Api from '~/api';
import ServiceAccountsException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/service_accounts_exception.vue';
import PolicyExceptionsLoader from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions_loader.vue';

jest.mock('~/api');

describe('ServiceAccountsException', () => {
  let wrapper;

  const mockRootNamespacePath = 'gitlab-org';
  const mockServiceAccounts = [{ id: 1 }, { id: 2 }, { id: 3 }];
  const mockApiAccounts = [
    { id: 1, name: 'Service Account 1' },
    { id: 2, name: 'Service Account 2' },
    { id: 4, name: 'Service Account 4' },
  ];

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ServiceAccountsException, {
      propsData,
      provide: {
        rootNamespacePath: mockRootNamespacePath,
        ...provide,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findLoader = () => wrapper.findComponent(PolicyExceptionsLoader);
  const findAccountItems = () => wrapper.findAllByTestId('account-item');
  const findBackUpAccountItems = () => wrapper.findAllByTestId('backup-account-item');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct header level', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('displays correct title with zero count', () => {
      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (0)');
    });

    it('does not render loading icon initially', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('does not render any account items when service accounts array is empty', () => {
      expect(findAccountItems()).toHaveLength(0);
    });
  });

  describe('with service accounts', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (3)');
    });
  });

  describe('accordion interaction', () => {
    beforeEach(() => {
      Api.groupServiceAccounts.mockResolvedValue({ data: mockApiAccounts });
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });
    });

    it('does not load accounts when accordion is closed', () => {
      findAccordionItem().vm.$emit('input', false);

      expect(Api.groupServiceAccounts).not.toHaveBeenCalled();
    });

    it('does not reload accounts when accordion is opened again', async () => {
      // First open
      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(Api.groupServiceAccounts).toHaveBeenCalledTimes(1);

      // Second open
      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(Api.groupServiceAccounts).toHaveBeenCalledTimes(1);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      Api.groupServiceAccounts.mockImplementation(() => new Promise(() => {})); // Never resolves
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });
    });

    it('shows loading state when fetching accounts', async () => {
      await findAccordionItem().vm.$emit('input', true);

      expect(findLoader().exists()).toBe(true);
      expect(findLoader().props('label')).toBe('Loading accounts');
    });
  });

  describe('successful account loading', () => {
    beforeEach(async () => {
      Api.groupServiceAccounts.mockResolvedValue({ data: mockApiAccounts });
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();
    });

    it('renders selected accounts correctly', () => {
      const accountItems = findAccountItems();
      expect(accountItems).toHaveLength(2); // Only accounts with IDs 1 and 2 should be shown
      expect(accountItems.at(0).text()).toBe('Service Account 1');
      expect(accountItems.at(1).text()).toBe('Service Account 2');
    });

    it('does not show loading icon after successful load', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('error handling', () => {
    beforeEach(async () => {
      Api.groupServiceAccounts.mockRejectedValue(new Error('API Error'));
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();
    });

    it('shows account IDs when loading fails', () => {
      const accountItems = findBackUpAccountItems();
      expect(accountItems).toHaveLength(3);
      expect(accountItems.at(0).text()).toBe('id: 1');
      expect(accountItems.at(1).text()).toBe('id: 2');
      expect(accountItems.at(2).text()).toBe('id: 3');
    });

    it('does not show loading icon when error occurs', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('edge cases', () => {
    it('handles empty service accounts gracefully', () => {
      createComponent({
        propsData: {
          serviceAccounts: [],
        },
      });

      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (0)');
    });

    it('handles service accounts without id property', () => {
      const invalidServiceAccounts = [{ name: 'Invalid Account' }];
      createComponent({
        propsData: {
          serviceAccounts: invalidServiceAccounts,
        },
      });

      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (1)');
    });

    it('handles API response without data property', async () => {
      Api.groupServiceAccounts.mockResolvedValue({});
      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(findAccountItems()).toHaveLength(0);
    });
  });

  describe('different service account configurations', () => {
    it('renders correctly with single service account', () => {
      createComponent({
        propsData: {
          serviceAccounts: [{ id: 1 }],
        },
      });

      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (1)');
    });

    it('renders correctly with multiple service accounts', () => {
      createComponent({
        propsData: {
          serviceAccounts: [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }],
        },
      });

      expect(findAccordionItem().props('title')).toBe('Accounts exceptions (5)');
    });
  });

  describe('API integration', () => {
    it('calls API when accordion is opened', async () => {
      Api.groupServiceAccounts.mockResolvedValue({ data: [] });

      createComponent({
        propsData: {
          serviceAccounts: mockServiceAccounts,
        },
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(Api.groupServiceAccounts).toHaveBeenCalledTimes(1);
    });

    it('handles partial account matches correctly', async () => {
      const partialMatchAccounts = [
        { id: 1, name: 'Account 1' },
        { id: 5, name: 'Account 5' }, // This ID is not in mockServiceAccounts
      ];

      Api.groupServiceAccounts.mockResolvedValue({ data: partialMatchAccounts });
      createComponent({
        propsData: {
          serviceAccounts: [{ id: 1 }, { id: 2 }, { id: 3 }],
        },
      });

      findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      const accountItems = findAccountItems();
      expect(accountItems).toHaveLength(1); // Only ID 1 should match
      expect(accountItems.at(0).text()).toBe('Account 1');
    });
  });
});
