import { nextTick } from 'vue';
import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Api from '~/api';
import ServiceAccountsSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_selector.vue';
import ServiceAccountsItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_item.vue';
import { mockAccounts, mockSelectedAccounts } from './mocks';

jest.mock('~/api');

describe('TokensSelector', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ServiceAccountsSelector, {
      propsData: {
        selectedAccounts: [],
        ...props,
      },
      provide: {
        rootNamespacePath: 'test-project',
        ...provide,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findServiceAccountsItems = () => wrapper.findAllComponents(ServiceAccountsItem);
  const findAddServiceAccountButton = () => wrapper.findComponentByTestId('add-service-account');

  beforeEach(() => {
    Api.groupServiceAccounts.mockResolvedValue({ data: mockAccounts });
  });

  describe('rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders default service account item', () => {
      expect(findAddServiceAccountButton().props('disabled')).toBe(false);

      expect(findServiceAccountsItems()).toHaveLength(1);
      expect(findServiceAccountsItems().at(0).props('serviceAccounts')).toEqual(mockAccounts);
      expect(findServiceAccountsItems().at(0).props('alreadySelectedIds')).toEqual([]);
    });

    it('does not render alert initially', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('adds new service account item', async () => {
      await findAddServiceAccountButton().vm.$emit('click');

      expect(findServiceAccountsItems()).toHaveLength(2);
    });
  });

  describe('API integration', () => {
    it('fetches service accounts on mount', () => {
      createComponent();

      expect(Api.groupServiceAccounts).toHaveBeenCalledTimes(1);
      expect(Api.groupServiceAccounts).toHaveBeenCalledWith('test-project');
    });

    it('shows loading state while fetching tokens', async () => {
      createComponent();
      await nextTick();

      expect(findServiceAccountsItems().at(0).props('loading')).toBe(true);
      expect(findAddServiceAccountButton().props('disabled')).toBe(true);
    });

    it('shows alert when API call fails', async () => {
      Api.groupServiceAccounts.mockRejectedValue(new Error('API Error'));
      createComponent();
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
      expect(findAlert().text()).toBe('Error while fetching');
    });

    it('show alert message when there is a fetch error', async () => {
      createComponent();

      await findServiceAccountsItems().at(0).vm.$emit('token-loading-error');
      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('account selection', () => {
    beforeEach(async () => {
      createComponent({
        selectedAccounts: mockSelectedAccounts,
      });
      await waitForPromises();
    });

    it('displays selected accounts correctly', () => {
      const serviceAccounts = findServiceAccountsItems();
      expect(serviceAccounts).toHaveLength(2);

      expect(serviceAccounts.at(0).props('selectedItem')).toEqual({
        id: '1',
      });
      expect(serviceAccounts.at(0).props('alreadySelectedIds')).toEqual(['1', '2']);

      expect(serviceAccounts.at(1).props('selectedItem')).toEqual({
        id: '2',
      });
      expect(serviceAccounts.at(1).props('alreadySelectedIds')).toEqual(['1', '2']);
    });

    it('emits set-accounts event when accounts are selected', () => {
      createComponent();
      const payload = { id: mockAccounts[0].id };
      findServiceAccountsItems().at(0).vm.$emit('set-account', payload);

      expect(wrapper.emitted('set-accounts')).toEqual([[[payload]]]);
    });
  });
});
