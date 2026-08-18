import { GlSearchBoxByType } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import BuildPolicyStep from 'ee/policy_store/components/editor/steps/build_policy_step.vue';
import CatalogSkeleton from 'ee/policy_store/components/editor/catalog_skeleton.vue';
import GenericConfig from 'ee/policy_store/components/editor/generic_config.vue';
import { emptyPolicyData } from 'ee/policy_store/components/editor/serializer';
import { ACTIONS } from 'ee/policy_store/catalog/actions';
import { RULES } from 'ee/policy_store/catalog/rules';
import { TRIGGERS } from 'ee/policy_store/catalog/triggers';

describe('BuildPolicyStep', () => {
  let wrapper;

  // GlTabs (bootstrap-vue) registers its tabs asynchronously, so the nav links only
  // exist a tick after mount.
  const createComponent = async (policyData = {}, props = {}) => {
    wrapper = mountExtended(BuildPolicyStep, {
      propsData: {
        policyData: { ...emptyPolicyData(), ...policyData },
        catalogs: { triggers: TRIGGERS, rules: RULES, actions: ACTIONS },
        ...props,
      },
    });
    await nextTick();
  };

  // The drawer shows one tab at a time, so reaching a rule or action means opening its tab first.
  const openTab = async (tab) => {
    await wrapper.findByTestId(`${tab}-tab`).trigger('click');
  };

  const findTabs = () => wrapper.findAll('[role="tab"]');
  const findOptions = (tab) => wrapper.findAllByTestId(`${tab}-option`);
  const findOption = (tab, label) =>
    findOptions(tab).wrappers.find((option) => option.text().includes(label));
  const findSelected = (section) => wrapper.findAllByTestId(`${section}-selected`);
  const findAddButton = (section) => wrapper.findByTestId(`${section}-add`);
  const lastUpdate = () => {
    const updates = wrapper.emitted('update');
    return updates[updates.length - 1][0];
  };

  describe('drawer', () => {
    it('renders a tab per building block, with triggers open first', async () => {
      await createComponent();

      expect(findTabs().wrappers.map((tab) => tab.text())).toEqual([
        'Triggers',
        'Rules',
        'Actions',
      ]);
      expect(wrapper.findByTestId('triggers-tab').attributes('aria-selected')).toBe('true');
      expect(wrapper.findByTestId('rules-tab').attributes('aria-selected')).toBe('false');
    });

    it('shows only the open tab’s catalog', async () => {
      await createComponent();

      expect(findOptions('triggers')).toHaveLength(1);
      expect(findOptions('rules')).toHaveLength(0);
    });

    it('lists the rules once its tab is open', async () => {
      await createComponent();

      await openTab('rules');

      expect(findOptions('rules')).toHaveLength(3);
    });

    it('lists the actions once its tab is open', async () => {
      await createComponent();

      await openTab('actions');

      expect(findOptions('actions')).toHaveLength(2);
    });

    it('groups entries by category', async () => {
      await createComponent();

      await openTab('rules');

      expect(wrapper.text()).toContain('Advanced');
      expect(wrapper.text()).toContain('Deployment');
    });

    it('marks a selected entry as pressed', async () => {
      await createComponent({ rules: ['custom'] });

      await openTab('rules');

      expect(findOption('rules', 'Custom Rule').attributes('aria-pressed')).toBe('true');
      expect(findOption('rules', 'Freeze Window').attributes('aria-pressed')).toBe('false');
    });

    it('lists the catalog it receives rather than the local one', async () => {
      await createComponent(
        {},
        {
          catalogs: {
            triggers: [
              {
                id: 't1',
                label: 'Remote trigger',
                description: '',
                icon: 'question-o',
                fields: [],
              },
            ],
            rules: [],
            actions: [],
          },
        },
      );

      expect(findOptions('triggers')).toHaveLength(1);
      expect(findOptions('triggers').at(0).text()).toContain('Remote trigger');
    });

    it('shows the skeleton instead of the catalog while the catalogs load', async () => {
      await createComponent({}, { catalogsLoading: true });

      expect(wrapper.findComponent(CatalogSkeleton).exists()).toBe(true);
      expect(findOptions('triggers')).toHaveLength(0);
    });

    it('shows no skeleton once the catalogs have loaded', async () => {
      await createComponent();

      expect(wrapper.findComponent(CatalogSkeleton).exists()).toBe(false);
      expect(findOptions('triggers')).toHaveLength(1);
    });
  });

  describe('catalog error', () => {
    it('shows the alert on the failed tab, naming its catalog, with the items hidden', async () => {
      await createComponent({}, { failedCatalogs: ['triggers'] });

      expect(wrapper.findByTestId('catalogs-error').text()).toContain(
        'The available triggers could not be fetched from the Policy Store API.',
      );
      expect(findOptions('triggers')).toHaveLength(0);
      expect(wrapper.findByTestId('triggers-no-results').exists()).toBe(false);
    });

    it('keeps the successful tabs intact when another catalog failed', async () => {
      await createComponent({}, { failedCatalogs: ['triggers'] });

      await openTab('rules');

      expect(wrapper.findByTestId('catalogs-error').exists()).toBe(false);
      expect(findOptions('rules')).toHaveLength(3);
    });

    it('names the open tab’s catalog when several catalogs failed', async () => {
      await createComponent({}, { failedCatalogs: ['triggers', 'actions'] });

      await openTab('actions');

      expect(wrapper.findByTestId('catalogs-error').text()).toContain(
        'The available actions could not be fetched from the Policy Store API.',
      );
      expect(findOptions('actions')).toHaveLength(0);
    });

    it('shows no error alert by default', async () => {
      await createComponent();

      expect(wrapper.findByTestId('catalogs-error').exists()).toBe(false);
    });
  });

  describe('trigger selection', () => {
    it('selects a trigger', async () => {
      await createComponent();

      findOption('triggers', 'Deployment').trigger('click');

      expect(lastUpdate().trigger).toBe('deployment_requested');
    });

    it('replaces the trigger rather than adding, since a policy stores one', async () => {
      await createComponent({ trigger: 'deployment_requested' });

      await openTab('triggers');
      findOption('triggers', 'Deployment').trigger('click');

      // The only trigger in scope, so re-clicking clears it rather than replacing.
      expect(lastUpdate().trigger).toBeNull();
    });

    it('clears the trigger config together with the selection', async () => {
      await createComponent({
        trigger: 'deployment_requested',
        triggerConfig: { environment: 'production' },
      });

      await openTab('triggers');
      findOption('triggers', 'Deployment').trigger('click');

      expect(lastUpdate().triggerConfig).toEqual({});
    });

    it('shows the selected trigger in the right panel', async () => {
      await createComponent({ trigger: 'deployment_requested' });

      expect(findSelected('triggers')).toHaveLength(1);
      expect(findSelected('triggers').at(0).text()).toContain('Deployment');
    });
  });

  describe('rule selection', () => {
    it('adds a rule without replacing the existing one', async () => {
      await createComponent({ rules: ['custom'] });

      await openTab('rules');
      findOption('rules', 'Freeze Window').trigger('click');

      expect(lastUpdate().rules).toEqual(['custom', 'calendar']);
    });

    it('removes a rule when its catalog entry is clicked again', async () => {
      await createComponent({ rules: ['custom', 'calendar'] });

      await openTab('rules');
      findOption('rules', 'Custom Rule').trigger('click');

      expect(lastUpdate().rules).toEqual(['calendar']);
    });

    it('shows each selected rule in the right panel', async () => {
      await createComponent({ rules: ['custom', 'environment'] });

      expect(findSelected('rules')).toHaveLength(2);
    });

    it('joins selected rules with AND', async () => {
      await createComponent({ rules: ['custom', 'environment'] });

      expect(wrapper.text()).toContain('AND');
    });

    it('falls back to the raw id for a selection the catalog no longer knows', async () => {
      await createComponent({ rules: ['retired_rule'] });

      expect(findSelected('rules').at(0).text()).toContain('retired_rule');
      expect(wrapper.findByTestId('rules-selected-remove').attributes('aria-label')).toBe(
        'Remove retired_rule',
      );
    });
  });

  describe('configuration', () => {
    it('renders the config form for a selected rule with fields', async () => {
      await createComponent({ rules: ['environment'] });

      expect(wrapper.findComponent(GenericConfig).props('fields')).toHaveLength(1);
    });

    it('renders no config form for the trigger, which declares no fields', async () => {
      await createComponent({ trigger: 'deployment_requested' });

      expect(wrapper.findComponent(GenericConfig).exists()).toBe(false);
    });

    it('records a rule config against that rule only', async () => {
      await createComponent({ rules: ['environment'] });

      wrapper.findComponent(GenericConfig).vm.$emit('input', { environment: 'production' });

      expect(lastUpdate().ruleConfigs).toEqual({
        environment: { environment: 'production' },
      });
    });

    it('keeps other rules’ configs when one changes', async () => {
      await createComponent({
        rules: ['environment', 'calendar'],
        ruleConfigs: { calendar: { timezone: 'UTC' } },
      });

      wrapper.findComponent(GenericConfig).vm.$emit('input', { environment: 'prod' });

      expect(lastUpdate().ruleConfigs).toEqual({
        calendar: { timezone: 'UTC' },
        environment: { environment: 'prod' },
      });
    });
  });

  describe('removing from the right panel', () => {
    it('removes a rule via its close button', async () => {
      await createComponent({ rules: ['custom', 'calendar'] });

      wrapper.findAllByTestId('rules-selected-remove').at(0).trigger('click');

      expect(lastUpdate().rules).toEqual(['calendar']);
    });

    it('keeps the configs of the remaining rules when one is removed', async () => {
      await createComponent({
        rules: ['custom', 'calendar'],
        ruleConfigs: { custom: { policy: 'package x' }, calendar: { timezone: 'UTC' } },
      });

      wrapper.findAllByTestId('rules-selected-remove').at(0).trigger('click');

      expect(lastUpdate().ruleConfigs).toEqual({
        custom: { policy: 'package x' },
        calendar: { timezone: 'UTC' },
      });
    });

    it('clears the trigger config when the trigger is removed', async () => {
      await createComponent({
        trigger: 'deployment_requested',
        triggerConfig: { environment: 'production' },
      });

      wrapper.findByTestId('triggers-selected-remove').trigger('click');

      expect(lastUpdate().trigger).toBeNull();
      expect(lastUpdate().triggerConfig).toEqual({});
    });
  });

  describe('action selection', () => {
    it('adds an action', async () => {
      await createComponent({ actions: ['block'] });

      await openTab('actions');
      findOption('actions', 'Require approval').trigger('click');

      expect(lastUpdate().actions).toEqual(['block', 'require_approval']);
    });
  });

  describe('search', () => {
    it('filters the open tab by label', async () => {
      await createComponent();

      await openTab('rules');
      wrapper.findComponent(GlSearchBoxByType).vm.$emit('input', 'state');
      await nextTick();

      expect(findOptions('rules')).toHaveLength(1);
      expect(findOptions('rules').at(0).text()).toContain('Environment State');
    });

    it('filters by description', async () => {
      await createComponent();

      await openTab('rules');
      wrapper.findComponent(GlSearchBoxByType).vm.$emit('input', 'freeze periods');
      await nextTick();

      expect(findOptions('rules')).toHaveLength(1);
      expect(findOptions('rules').at(0).text()).toContain('Freeze Window');
    });

    it('shows a no-results message when nothing matches', async () => {
      await createComponent();

      await openTab('rules');
      wrapper.findComponent(GlSearchBoxByType).vm.$emit('input', 'nothing matches this');
      await nextTick();

      expect(wrapper.findByTestId('rules-no-results').exists()).toBe(true);
    });
  });

  describe('empty sections', () => {
    it.each([
      ['triggers', 'Add trigger'],
      ['rules', 'Add rule'],
      ['actions', 'Add action'],
    ])('offers an add button for the empty %s section', async (section, label) => {
      await createComponent();

      expect(findAddButton(section).text()).toBe(label);
    });

    it('opens the matching tab when the add button is clicked', async () => {
      await createComponent();

      await findAddButton('actions').trigger('click');

      expect(wrapper.findByTestId('actions-tab').attributes('aria-selected')).toBe('true');
      expect(findOptions('actions')).toHaveLength(2);
    });

    it('hides the add button once the section has an entry', async () => {
      await createComponent({ rules: ['custom'] });

      expect(findAddButton('rules').exists()).toBe(false);
    });
  });
});
