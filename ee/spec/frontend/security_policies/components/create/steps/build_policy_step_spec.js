import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlSearchBoxByType } from '@gitlab/ui';
import BuildPolicyStep from 'ee/security_policies/components/create/steps/build_policy_step.vue';
import GenericConfig from 'ee/security_policies/components/create/generic_config.vue';

jest.mock('ee/security_orchestration/components/yaml_editor.vue', () => ({
  name: 'YamlEditor',
  props: ['value', 'readOnly', 'disableSchema'],
  render(h) {
    return h('div', { attrs: { 'data-testid': 'yaml-editor' } });
  },
}));

const defaultPolicyData = { trigger: null, rules: [], actions: [], scope: 'all' };

describe('BuildPolicyStep', () => {
  let wrapper;

  const createComponent = (policyData = defaultPolicyData) => {
    wrapper = shallowMount(BuildPolicyStep, { propsData: { policyData } });
  };

  const findTabButtons = () =>
    wrapper
      .findAll('button')
      .wrappers.filter((b) => ['Triggers', 'Rules', 'Actions'].some((t) => b.text().startsWith(t)));
  const findSearch = () => wrapper.findComponent(GlSearchBoxByType);
  const findTriggerButtons = () =>
    wrapper.findAll('button').wrappers.filter((b) => b.find('span.gl-truncate').exists());
  const findGenericConfigs = () => wrapper.findAllComponents(GenericConfig);

  it('renders left drawer with pill tab nav', () => {
    createComponent();

    expect(findTabButtons()).toHaveLength(3);
  });

  it('renders search box', () => {
    createComponent();

    expect(findSearch().exists()).toBe(true);
  });

  it('renders trigger items categorized in the left panel', () => {
    createComponent();

    expect(findTriggerButtons().length).toBeGreaterThan(0);
  });

  it('renders AI banner by default', () => {
    createComponent();

    expect(wrapper.text()).toContain('Draft your policy with GitLab Duo');
  });

  it('hides AI banner when dismissed', async () => {
    createComponent();

    wrapper.vm.showAiBanner = false;
    await nextTick();

    expect(wrapper.text()).not.toContain('Draft your policy with GitLab Duo');
  });

  it('shows triggers section subtitle when no trigger selected', () => {
    createComponent();

    expect(wrapper.text()).toContain('When should this policy be evaluated?');
  });

  it('shows rules section subtitle when no rules added', () => {
    createComponent();

    expect(wrapper.text()).toContain('What conditions must be met?');
  });

  it('shows actions section subtitle when no actions added', () => {
    createComponent();

    expect(wrapper.text()).toContain('What happens when rules are matched?');
  });

  it('shows Add trigger button', () => {
    createComponent();

    expect(wrapper.text()).toContain('Add trigger');
  });

  it('selecting a trigger shows it in the right panel', async () => {
    createComponent();

    wrapper.vm.triggers = ['merge_request'];
    wrapper.vm.expandedTriggers = { merge_request: true };
    await nextTick();

    expect(wrapper.text()).toContain('Merge Request');
    expect(findGenericConfigs().length).toBeGreaterThan(0);
  });

  it('clicking a trigger button emits update with trigger id', async () => {
    createComponent();

    const btn = findTriggerButtons()[0];
    await btn.trigger('click');

    expect(wrapper.emitted('update')).toBeDefined();
    expect(wrapper.emitted('update')[0][0]).toHaveProperty('triggers');
  });

  it('clicking same trigger again deselects it', async () => {
    createComponent();

    const btn = findTriggerButtons()[0];
    await btn.trigger('click');
    const firstTriggerId = wrapper.emitted('update')[0][0].triggers[0];

    await btn.trigger('click');

    expect(wrapper.emitted('update')[1][0].triggers).toHaveLength(0);
    expect(firstTriggerId).not.toBeNull();
  });

  it('shows check icon on selected trigger', async () => {
    createComponent();

    const btn = findTriggerButtons()[0];
    await btn.trigger('click');

    const checkIcon = wrapper
      .findAllComponents(GlIcon)
      .wrappers.find((i) => i.props('name') === 'check-circle-filled');
    expect(checkIcon).toBeDefined();
  });

  it('adding a rule shows it in the right panel', async () => {
    createComponent();

    wrapper.vm.rules = ['scan_finding'];
    await nextTick();

    expect(wrapper.text()).toContain('Scan Finding');
  });

  it('emits update with rules array when rule is added', async () => {
    createComponent();

    await wrapper.vm.clickRule('scan_finding');

    const lastEmit = wrapper.emitted('update').at(-1)[0];
    expect(lastEmit.rules).toContain('scan_finding');
  });

  it('removes rule when same rule is clicked again', async () => {
    createComponent({ ...defaultPolicyData, rules: ['scan_finding'] });

    await wrapper.vm.clickRule('scan_finding');

    const lastEmit = wrapper.emitted('update').at(-1)[0];
    expect(lastEmit.rules).not.toContain('scan_finding');
  });

  it('filters items by search query', async () => {
    createComponent();

    const allCount = findTriggerButtons().length;
    wrapper.vm.search = 'merge';
    await nextTick();

    expect(findTriggerButtons().length).toBeLessThan(allCount);
  });

  it('shows rule count badge in tab label', async () => {
    createComponent();

    wrapper.vm.rules = ['scan_finding', 'pipeline'];
    await nextTick();

    expect(wrapper.vm.tabLabel(1)).toContain('(2)');
  });

  it('tab label has no count when empty', () => {
    createComponent();

    expect(wrapper.vm.tabLabel(1)).not.toContain('(');
  });

  it('defaults to visual mode (yamlMode is false)', () => {
    createComponent();

    expect(wrapper.vm.yamlMode).toBe(false);
  });

  it('hides left drawer in YAML mode', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    await nextTick();

    expect(findTabButtons()).toHaveLength(0);
  });

  it('shows YAML editor heading when yamlMode is true', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    await nextTick();

    expect(wrapper.text()).toContain('YAML editor');
  });

  it('shows YAML content when yamlMode is true', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    await nextTick();

    expect(wrapper.vm.yamlContent).toContain('triggers:');
  });

  it('YAML content includes selected trigger', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    wrapper.vm.triggers = ['merge_request'];
    await nextTick();

    expect(wrapper.vm.yamlContent).toContain('merge_request');
  });

  it('hides visual sections when in YAML mode', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    await nextTick();

    expect(wrapper.text()).not.toContain('When should this policy be evaluated?');
  });

  it('yamlContent is editable via yamlText', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    wrapper.vm.yamlText = 'custom: yaml';
    await nextTick();

    expect(wrapper.vm.yamlContent).toBe('custom: yaml');
  });

  it('resets yamlText when switching back to visual', async () => {
    createComponent();

    wrapper.vm.yamlMode = true;
    wrapper.vm.yamlText = 'custom: yaml';
    await nextTick();
    wrapper.vm.yamlMode = false;
    await nextTick();

    expect(wrapper.vm.yamlText).toBeNull();
  });

  it('section headers do not render Add buttons separate from add-item buttons', () => {
    createComponent();

    const addButtons = wrapper.findAll('button').wrappers.filter((b) => b.text().includes('+ Add'));
    expect(addButtons).toHaveLength(0);
  });
});
