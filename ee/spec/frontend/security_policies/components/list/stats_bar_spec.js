import { shallowMount } from '@vue/test-utils';
import { GlIcon } from '@gitlab/ui';
import StatsBar from 'ee/security_policies/components/list/stats_bar.vue';

const defaultProps = {
  activePolicies: { total: 30, enforcing: 18, warning: 8, audit: 4 },
  actionsThisWeek: { blocked: 175, warned: 168, logged: 67 },
  catching: { count: 11 },
  needsAttention: { total: 6, drafts: 3, disabled: 2, pendingApproval: 1 },
};

describe('StatsBar', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(StatsBar, { propsData: { ...defaultProps, ...propsData } });
  };

  it('renders active policies count', () => {
    createComponent();

    expect(wrapper.text()).toContain('30');
    expect(wrapper.text()).toContain('18 enforcing');
    expect(wrapper.text()).toContain('8 warning');
    expect(wrapper.text()).toContain('4 audit');
  });

  it('renders actions this week counts', () => {
    createComponent();

    expect(wrapper.text()).toContain('175');
    expect(wrapper.text()).toContain('168');
    expect(wrapper.text()).toContain('67');
  });

  it('renders catching count', () => {
    createComponent();

    expect(wrapper.text()).toContain('11');
  });

  it('renders needs attention count and breakdown', () => {
    createComponent();

    expect(wrapper.text()).toContain('6');
    expect(wrapper.text()).toContain('3 drafts');
    expect(wrapper.text()).toContain('2 disabled');
    expect(wrapper.text()).toContain('1 pending approval');
  });

  it('renders colored icons for blocked/warned/logged', () => {
    createComponent();

    const icons = wrapper.findAllComponents(GlIcon).wrappers;
    expect(icons.some((i) => i.props('name') === 'dash-circle')).toBe(true);
    expect(icons.some((i) => i.props('name') === 'warning')).toBe(true);
    expect(icons.some((i) => i.props('name') === 'doc-text')).toBe(true);
  });

  it('emits filter-blocked when blocked button clicked', async () => {
    createComponent();

    const blockedBtn = wrapper.find('button:first-of-type');
    await blockedBtn.trigger('click');

    expect(wrapper.emitted('filter-blocked')).toBeDefined();
  });

  it('emits filter-catching when catching tile is clicked', async () => {
    createComponent();

    const catchingBtn = wrapper
      .findAll('button')
      .wrappers.find((b) => b.text().includes('Catching'));
    await catchingBtn.trigger('click');

    expect(wrapper.emitted('filter-catching')).toBeDefined();
  });

  it('emits filter-needs-attention when needs attention tile is clicked', async () => {
    createComponent();

    const attentionBtn = wrapper
      .findAll('button')
      .wrappers.find((b) => b.text().includes('Needs attention'));
    await attentionBtn.trigger('click');

    expect(wrapper.emitted('filter-needs-attention')).toBeDefined();
  });

  it('uses zero defaults when no props passed', () => {
    wrapper = shallowMount(StatsBar);

    expect(wrapper.text()).toContain('0');
  });
});
