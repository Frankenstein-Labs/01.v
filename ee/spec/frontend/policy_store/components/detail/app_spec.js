import { shallowMount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import App from 'ee/policy_store/components/detail/app.vue';
import SummarySection from 'ee/policy_store/components/detail/summary_section.vue';
import { fetchPolicy, updatePolicy, deletePolicy } from 'ee/policy_store/policies';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('ee/policy_store/policies', () => ({
  fetchPolicy: jest.fn(),
  updatePolicy: jest.fn(),
  deletePolicy: jest.fn(),
}));

describe('PolicyStoreDetailRoot', () => {
  let wrapper;

  const policy = {
    id: 7,
    name: 'Production gate',
    description: 'Gates production deployments',
    type: 'Deployment',
    trigger_type: 'deployment_requested',
    rules: [{ type: 'custom', value: 'package governance' }],
    actions: [{ type: 'block' }],
    mode: 'enforce',
    status: 'active',
    scopedProjectsCount: 3,
  };

  const createComponent = async (provide = {}) => {
    wrapper = shallowMount(App, {
      provide: {
        organizationId: '1',
        policyId: '7',
        listPath: '/-/security/policy_store',
        editPath: '/-/security/policy_store/7/edit',
        ...provide,
      },
      stubs: {
        SummarySection: stubComponent(SummarySection, {
          template: '<section><slot></slot></section>',
        }),
      },
    });
    await waitForPromises();
  };

  const findByTestId = (id) => wrapper.find(`[data-testid="${id}"]`);
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findSections = () => wrapper.findAllComponents(SummarySection);
  const findSection = (testid) =>
    findSections().wrappers.find((section) => section.props('testid') === testid);
  const findDeleteButton = () => wrapper.findComponent('[data-testid="delete-policy-button"]');

  beforeEach(() => {
    fetchPolicy.mockResolvedValue(policy);
    updatePolicy.mockResolvedValue({ ...policy, status: 'disabled' });
    deletePolicy.mockResolvedValue();
    confirmAction.mockResolvedValue(true);
  });

  it('fetches the policy through the single-policy endpoint', async () => {
    await createComponent();

    expect(fetchPolicy).toHaveBeenCalledWith('1', '7');
  });

  it('renders the header with name, badges, and description', async () => {
    await createComponent();

    expect(findByTestId('policy-name').text()).toBe('Production gate');
    expect(findByTestId('policy-description').text()).toBe('Gates production deployments');
    expect(findBadges().wrappers.map((badge) => badge.text())).toEqual([
      'Deployment',
      'Enforce',
      'Active',
    ]);
  });

  it('renders no description paragraph when the policy has none', async () => {
    fetchPolicy.mockResolvedValue({ ...policy, description: '' });

    await createComponent();

    expect(findByTestId('policy-description').exists()).toBe(false);
  });

  it('passes catalog-resolved entries to the trigger, rules, and actions sections', async () => {
    await createComponent();

    expect(findSections().wrappers.map((section) => section.props('label'))).toEqual([
      'Trigger',
      'Rules',
      'Actions',
      'Scope',
    ]);
    expect(findSection('trigger').props('entries')).toEqual([
      expect.objectContaining({ label: 'Deployment' }),
    ]);
    expect(findSection('rules').props('entries')).toEqual([
      expect.objectContaining({ label: 'Custom Rule (Rego)' }),
    ]);
    expect(findSection('actions').props('entries')).toEqual([
      expect.objectContaining({ label: 'Block' }),
    ]);
  });

  it('falls back to the raw id for an entry the catalog no longer knows', async () => {
    fetchPolicy.mockResolvedValue({ ...policy, rules: [{ type: 'retired_rule', value: {} }] });

    await createComponent();

    expect(findSection('rules').props('entries')).toEqual([
      expect.objectContaining({ id: 'retired_rule', label: 'retired_rule', icon: 'question-o' }),
    ]);
  });

  it('passes no entries for a section with nothing configured', async () => {
    fetchPolicy.mockResolvedValue({ ...policy, actions: [] });

    await createComponent();

    expect(findSection('actions').props('entries')).toEqual([]);
  });

  it('summarises the scope in a summary section from the scoped project count', async () => {
    await createComponent();

    expect(findSection('scope').props('label')).toBe('Scope');
    expect(findSection('scope').text()).toContain('3 projects');
  });

  it('labels an unscoped policy as applying to all projects', async () => {
    fetchPolicy.mockResolvedValue({ ...policy, scopedProjectsCount: 0 });

    await createComponent();

    expect(findSection('scope').text()).toContain('All projects');
  });

  it('links the edit button to the edit path', async () => {
    await createComponent();

    expect(findByTestId('edit-policy-button').attributes('href')).toBe(
      '/-/security/policy_store/7/edit',
    );
  });

  it('shows a loading icon instead of the page while the policy loads', () => {
    fetchPolicy.mockReturnValue(new Promise(() => {}));

    wrapper = shallowMount(App, {
      provide: { organizationId: '1', policyId: '7', listPath: '', editPath: '' },
    });

    expect(findByTestId('policy-loading').exists()).toBe(true);
    expect(findByTestId('policy-name').exists()).toBe(false);
  });

  it('shows an error instead of the page when the policy fails to load', async () => {
    const error = new Error('not found');
    fetchPolicy.mockRejectedValue(error);

    await createComponent();

    expect(findByTestId('policy-error').text()).toContain(
      'The policy could not be loaded from the Policy Store API.',
    );
    expect(findByTestId('policy-name').exists()).toBe(false);
    expect(Sentry.captureException).toHaveBeenCalledWith(error);
  });

  describe('toggling the policy status', () => {
    const findToggleButton = () => wrapper.findComponent('[data-testid="toggle-status-button"]');

    const requestToggle = async () => {
      findToggleButton().vm.$emit('click');
      await waitForPromises();
    };

    it('offers Disable for an active policy and Enable for a disabled one', async () => {
      await createComponent();
      expect(findToggleButton().text()).toBe('Disable');

      fetchPolicy.mockResolvedValue({ ...policy, status: 'disabled' });
      await createComponent();
      expect(findToggleButton().text()).toBe('Enable');
    });

    it('disables an active policy and refreshes the badge without navigating', async () => {
      await createComponent();

      await requestToggle();

      expect(updatePolicy).toHaveBeenCalledWith('1', '7', { lifecycle_state: 'disabled' });
      expect(findByTestId('policy-status').text()).toBe('Disabled');
      expect(findToggleButton().text()).toBe('Enable');
      expect(visitUrl).not.toHaveBeenCalled();
    });

    it('re-enables a disabled policy', async () => {
      fetchPolicy.mockResolvedValue({ ...policy, status: 'disabled' });
      updatePolicy.mockResolvedValue(policy);
      await createComponent();

      await requestToggle();

      expect(updatePolicy).toHaveBeenCalledWith('1', '7', { lifecycle_state: 'active' });
      expect(findByTestId('policy-status').text()).toBe('Active');
    });

    it('marks the button busy while the request is in flight', async () => {
      updatePolicy.mockReturnValue(new Promise(() => {}));
      await createComponent();

      await requestToggle();

      expect(findToggleButton().props('loading')).toBe(true);
    });

    it('keeps the status and alerts generically when the update fails', async () => {
      const error = new Error('API is down');
      updatePolicy.mockRejectedValue(error);
      await createComponent();

      await requestToggle();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'The policy could not be updated. Try again.',
      });
      expect(findByTestId('policy-status').text()).toBe('Active');
      expect(findToggleButton().props('loading')).toBe(false);
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it("surfaces the store's message when the update is rejected as invalid", async () => {
      const error = new Error('bad request');
      error.response = { data: { message: 'Lifecycle state is invalid' } };
      updatePolicy.mockRejectedValue(error);
      await createComponent();

      await requestToggle();

      expect(createAlert).toHaveBeenCalledWith({ message: 'Lifecycle state is invalid' });
    });
  });

  describe('deleting the policy', () => {
    const requestDelete = async () => {
      findDeleteButton().vm.$emit('click');
      await waitForPromises();
    };

    it('asks for confirmation naming the policy', async () => {
      await createComponent();

      await requestDelete();

      expect(confirmAction).toHaveBeenCalledWith(
        'Are you sure you want to delete Production gate? This action cannot be undone.',
        expect.objectContaining({ primaryBtnVariant: 'danger' }),
      );
    });

    it('deletes the policy and returns to the list', async () => {
      await createComponent();

      await requestDelete();

      expect(deletePolicy).toHaveBeenCalledWith('1', '7');
      expect(visitUrl).toHaveBeenCalledWith('/-/security/policy_store');
    });

    it('does not delete when the confirmation is declined', async () => {
      confirmAction.mockResolvedValue(false);
      await createComponent();

      await requestDelete();

      expect(deletePolicy).not.toHaveBeenCalled();
      expect(visitUrl).not.toHaveBeenCalled();
      expect(findDeleteButton().props('loading')).toBe(false);
    });

    it('ignores further clicks while the confirmation is pending', async () => {
      confirmAction.mockReturnValue(new Promise(() => {}));
      await createComponent();

      findDeleteButton().vm.$emit('click');
      findDeleteButton().vm.$emit('click');
      await waitForPromises();

      expect(confirmAction).toHaveBeenCalledTimes(1);
      expect(findDeleteButton().props('loading')).toBe(true);
    });

    it('resets the busy state after deleting when there is no list path to return to', async () => {
      await createComponent({ listPath: '' });

      await requestDelete();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(findDeleteButton().props('loading')).toBe(false);
    });

    it('marks the delete button busy while the request is in flight', async () => {
      deletePolicy.mockReturnValue(new Promise(() => {}));
      await createComponent();

      await requestDelete();

      expect(findDeleteButton().props('loading')).toBe(true);
    });

    it('stays on the page and alerts when the delete fails', async () => {
      const error = new Error('API is down');
      deletePolicy.mockRejectedValue(error);
      await createComponent();

      await requestDelete();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'The policy could not be deleted. Try again.',
      });
      expect(visitUrl).not.toHaveBeenCalled();
      expect(findDeleteButton().props('loading')).toBe(false);
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });
});
