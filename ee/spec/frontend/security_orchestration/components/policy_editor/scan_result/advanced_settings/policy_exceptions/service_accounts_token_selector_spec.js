import { GlCollapsibleListbox, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceAccountsTokenSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_token_selector.vue';
import waitForPromises from 'helpers/wait_for_promises';
import Api from '~/api';
import { mockTokens } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

jest.mock('~/api');

describe('ServiceAccountsTokenSelector', () => {
  let wrapper;

  const ACCOUNT_ID = 123;
  const LIST_BOX_ITEMS = mockTokens.map(({ id, name, full_name: fullName }) => ({
    value: id,
    text: name,
    fullName,
  }));

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(ServiceAccountsTokenSelector, {
      propsData,
      provide: {
        rootNamespacePath: 'test-project',
      },
    });
  };

  const findTokenListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findPopover = () => wrapper.findComponent(GlPopover);

  beforeEach(() => {
    Api.groupServiceAccountsTokens.mockResolvedValue({ data: mockTokens });
  });

  describe('default rendering', () => {
    it('does not load tokens when there is no accountId', async () => {
      createComponent();
      await waitForPromises();

      expect(Api.groupServiceAccountsTokens).not.toHaveBeenCalled();
      expect(findTokenListBox().props('items')).toHaveLength(0);
      expect(findTokenListBox().props('disabled')).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('renders loading state', () => {
      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });

      expect(findTokenListBox().props('loading')).toBe(true);
    });

    it('renders loaded tokens', async () => {
      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });
      await waitForPromises();

      expect(Api.groupServiceAccountsTokens).toHaveBeenCalledTimes(1);
      expect(Api.groupServiceAccountsTokens).toHaveBeenCalledWith('test-project', ACCOUNT_ID);

      expect(findTokenListBox().props('loading')).toBe(false);
      expect(findTokenListBox().props('items')).toEqual(LIST_BOX_ITEMS);
      expect(findTokenListBox().props('disabled')).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });

    it('refetches tokens when account id is updated', async () => {
      createComponent();
      await waitForPromises();

      expect(Api.groupServiceAccountsTokens).not.toHaveBeenCalled();

      await wrapper.setProps({ accountId: ACCOUNT_ID });

      expect(Api.groupServiceAccountsTokens).toHaveBeenCalledTimes(1);
      expect(Api.groupServiceAccountsTokens).toHaveBeenCalledWith('test-project', ACCOUNT_ID);
    });
  });

  describe('selected tokens', () => {
    it('renders selected tokens', async () => {
      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
          selectedTokensIds: [1, 2],
        },
      });

      await waitForPromises();

      expect(findTokenListBox().props('selected')).toEqual([1, 2]);
      expect(findTokenListBox().props('toggleText')).toBe('project-token-1, project-token-2');
    });
  });

  describe('events', () => {
    it('filters tokens when searched', async () => {
      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });
      await waitForPromises();

      await findTokenListBox().vm.$emit('search', 'project-token-1');

      expect(findTokenListBox().props('items')).toEqual([LIST_BOX_ITEMS[0]]);
    });

    it('selects tokens', async () => {
      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });
      await waitForPromises();

      await findTokenListBox().vm.$emit('select', [1, 2]);

      expect(wrapper.emitted('set-tokens')).toEqual([[[{ id: 1 }, { id: 2 }]]]);
    });
  });

  describe('error state', () => {
    it('disables selector if there are no tokens loaded', async () => {
      Api.groupServiceAccountsTokens.mockResolvedValue({ data: [] });

      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });

      await waitForPromises();

      expect(findTokenListBox().props('items')).toEqual([]);
      expect(findTokenListBox().props('disabled')).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });

    it('emits error when fetching has failed', async () => {
      Api.groupServiceAccountsTokens.mockRejectedValue({});

      createComponent({
        propsData: {
          accountId: ACCOUNT_ID,
        },
      });

      await waitForPromises();

      expect(wrapper.emitted('loading-error')).toHaveLength(1);

      expect(findTokenListBox().props('items')).toEqual([]);
      expect(findTokenListBox().props('disabled')).toBe(true);
      expect(findPopover().exists()).toBe(true);
    });
  });
});
