import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import App from 'ee/policy_store/components/list/app.vue';
import ListWrapper from 'ee/policy_store/components/list/list_wrapper.vue';
import { fetchPolicies } from 'ee/policy_store/policies';
import { MOCK_EVALUATIONS_THIS_WEEK } from 'ee/policy_store/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('ee/policy_store/policies', () => ({
  fetchPolicies: jest.fn(),
}));

describe('PolicyStoreListRoot', () => {
  let wrapper;

  const policies = [
    { id: 1, name: 'Production gate', trigger_type: 'deployment_requested', status: 'active' },
    { id: 2, name: 'Merge gate', trigger_type: 'merge_request', status: 'active' },
  ];

  const findList = () => wrapper.findComponent(ListWrapper);
  const findError = () => wrapper.findComponent(GlAlert);

  const createComponent = async (provide = {}) => {
    wrapper = shallowMount(App, {
      provide: { organizationId: '1', ...provide },
    });
    await waitForPromises();
  };

  beforeEach(() => {
    fetchPolicies.mockResolvedValue(policies);
  });

  it('fetches the organization policies and passes them to the list with a detail path', async () => {
    await createComponent({ listPath: '/-/security/policy_store' });

    expect(fetchPolicies).toHaveBeenCalledWith('1');
    expect(findList().props('policies')).toEqual([
      { ...policies[0], detailPath: '/-/security/policy_store/1' },
      { ...policies[1], detailPath: '/-/security/policy_store/2' },
    ]);
    expect(findList().props('evaluationsThisWeek')).toBe(MOCK_EVALUATIONS_THIS_WEEK);
    expect(findList().props('loading')).toBe(false);
    expect(findError().exists()).toBe(false);
  });

  it('marks the list as loading while the fetch is in flight', () => {
    fetchPolicies.mockReturnValue(new Promise(() => {}));

    wrapper = shallowMount(App, { provide: { organizationId: '1' } });

    expect(findList().props('loading')).toBe(true);
  });

  it('leaves the detail path blank when no list path is provided', async () => {
    await createComponent();

    expect(findList().props('policies')).toEqual([
      { ...policies[0], detailPath: '' },
      { ...policies[1], detailPath: '' },
    ]);
  });

  it('passes the new policy path to the list', async () => {
    await createComponent({ newPolicyPath: '/-/security/policy_store/new' });

    expect(findList().props('newPolicyPath')).toBe('/-/security/policy_store/new');
  });

  it('shows the error alert and reports to Sentry when the fetch fails', async () => {
    const error = new Error('API is down');
    fetchPolicies.mockRejectedValue(error);

    await createComponent();

    expect(findError().text()).toContain(
      'The policies could not be fetched from the Policy Store API.',
    );
    expect(findList().props('policies')).toEqual([]);
    expect(findList().props('error')).toBe(true);
    expect(findList().props('loading')).toBe(false);
    expect(Sentry.captureException).toHaveBeenCalledWith(error);
  });

  it('refetches when the retry button on the error alert is clicked', async () => {
    fetchPolicies.mockRejectedValueOnce(new Error('API is down'));

    await createComponent();

    expect(findError().props('primaryButtonText')).toBe('Retry');

    findError().vm.$emit('primaryAction');
    await waitForPromises();

    expect(fetchPolicies).toHaveBeenCalledTimes(2);
    expect(findList().props('policies')).toEqual(
      policies.map((policy) => ({ ...policy, detailPath: '' })),
    );
    expect(findError().exists()).toBe(false);
  });

  it.each([401, 403, 404])(
    'shows a permission message and skips Sentry when the fetch fails with %d',
    async (status) => {
      const error = new Error('Denied');
      error.response = { status };
      fetchPolicies.mockRejectedValue(error);

      await createComponent();

      expect(findError().text()).toContain(
        'You do not have permission to view the policies of this organization.',
      );
      expect(findError().props('primaryButtonText')).toBe(null);
      expect(Sentry.captureException).not.toHaveBeenCalled();
    },
  );
});
