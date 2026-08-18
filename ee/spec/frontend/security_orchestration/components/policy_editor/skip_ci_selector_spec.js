import { GlToggle } from '@gitlab/ui';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';

describe('SkipCiSelector', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(SkipCiSelector, {
      propsData,
    });
  };

  const findAllowSkipCiSelector = () => wrapper.findComponent(GlToggle);
  const findUserSelect = () => wrapper.findComponent(UserSelect);

  it('renders not allow skip ci option by default', () => {
    createComponent();
    expect(findUserSelect().exists('resetOnEmpty')).toBe(true);
    expect(findUserSelect().exists()).toBe(true);
    expect(findAllowSkipCiSelector().exists()).toBe(true);

    expect(findAllowSkipCiSelector().props('value')).toBe(false);
    expect(findUserSelect().props('disabled')).toBe(true);
  });

  it('renders allow skip ci option by default for reversed option', () => {
    createComponent({
      isReversed: true,
    });

    expect(findAllowSkipCiSelector().props('value')).toBe(true);
    expect(findUserSelect().props('disabled')).toBe(false);
  });

  it('enabled skip ci skip option', () => {
    createComponent();

    findAllowSkipCiSelector().vm.$emit('change', true);

    expect(wrapper.emitted('changed')).toEqual([['skip_ci', { allowed: false }]]);
  });

  it('selects user exceptions', () => {
    createComponent({
      skipCiConfiguration: { allowed: false },
    });

    findUserSelect().vm.$emit('select-items', { user_approvers_ids: [1] });

    expect(wrapper.emitted('changed')).toEqual([
      ['skip_ci', { allowed: false, allowlist: { users: [{ id: 1 }] } }],
    ]);
  });

  it('renders user exceptions dropdown', () => {
    createComponent({
      skipCiConfiguration: { allowed: false, allowlist: { users: [{ id: 1 }, { id: 2 }] } },
    });

    expect(findUserSelect().props('selected')).toEqual([1, 2]);
  });

  it('selects user exceptions in graphql format', () => {
    createComponent({
      skipCiConfiguration: { allowed: false },
    });

    findUserSelect().vm.$emit('select-items', { user_approvers_ids: [1, 2] });

    expect(wrapper.emitted('changed')).toEqual([
      ['skip_ci', { allowed: false, allowlist: { users: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('renders user exceptions dropdown when skip ci is true', () => {
    createComponent({
      skipCiConfiguration: { allowed: true },
    });

    expect(findUserSelect().exists()).toBe(true);
    expect(findUserSelect().props('disabled')).toBe(true);
  });
});
