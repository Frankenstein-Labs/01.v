<script>
import { GlButton, GlIcon, GlSearchBoxByType, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ACTION_TYPES } from '../../../constants/action_types';
import { RULE_TYPES } from '../../../constants/rule_types';
import { TRIGGER_TYPES } from '../../../constants/trigger_types';
import GenericConfig from '../generic_config.vue';

const YamlEditor = () => import('ee/security_orchestration/components/yaml_editor.vue');

export default {
  name: 'BuildPolicyStep',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: { GlButton, GlIcon, GlSearchBoxByType, GenericConfig, YamlEditor },
  props: {
    policyData: {
      type: Object,
      required: true,
    },
    policyName: {
      type: String,
      required: false,
      default: '',
    },
    policyDescription: {
      type: String,
      required: false,
      default: '',
    },
    rawYaml: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['update'],
  i18n: {
    triggers: s__('SecurityOrchestration|Triggers'),
    triggersDesc: s__('SecurityOrchestration|When should this policy be evaluated?'),
    rules: s__('SecurityOrchestration|Rules'),
    rulesDesc: s__('SecurityOrchestration|What conditions must be met?'),
    actions: s__('SecurityOrchestration|Actions'),
    actionsDesc: s__('SecurityOrchestration|What happens when rules are matched?'),
    searchPlaceholder: s__('SecurityOrchestration|Search…'),
    visual: s__('SecurityOrchestration|Visual'),
    yaml: s__('SecurityOrchestration|YAML'),
    yamlEditor: s__('SecurityOrchestration|YAML editor'),
    yamlEditorDesc: s__(
      'SecurityOrchestration|Editing YAML directly will override the rule builder. Click "Use rule builder" to switch back.',
    ),
    addTrigger: s__('SecurityOrchestration|Add trigger'),
    addRule: s__('SecurityOrchestration|Add rule'),
    addAction: s__('SecurityOrchestration|Add action'),
    remove: s__('SecurityOrchestration|Remove'),
    custom: s__('SecurityOrchestration|Custom'),
    aiBanner: s__('SecurityOrchestration|Draft your policy with GitLab Duo'),
    tryIt: s__('SecurityOrchestration|Try it'),
    bundleBanner: s__(
      'SecurityOrchestration|Start faster with pre-built policy bundles for common security and compliance use cases.',
    ),
    browseBundleLibrary: s__('SecurityOrchestration|Browse the bundle library →'),
  },
  data() {
    return {
      search: '',
      activeTab: 0,
      showAiBanner: true,
      yamlMode: Boolean(this.rawYaml),
      hoveredItem: null,
      yamlText: this.rawYaml || null,
      triggers: [...(this.policyData.triggers || [])],
      triggerConfigs: { ...(this.policyData.triggerConfigs || {}) },
      expandedTriggers: {},
      rules: [...(this.policyData.rules || [])],
      ruleConfigs: { ...(this.policyData.ruleConfigs || {}) },
      expandedRules: {},
      actions: [...(this.policyData.actions || [])],
      actionConfigs: { ...(this.policyData.actionConfigs || {}) },
      expandedActions: {},
    };
  },
  computed: {
    triggersGrouped() {
      return this.groupedFor(TRIGGER_TYPES);
    },
    rulesGrouped() {
      return this.groupedFor(RULE_TYPES);
    },
    actionsGrouped() {
      return this.groupedFor(ACTION_TYPES);
    },
    yamlContent: {
      get() {
        return this.yamlText !== null ? this.yamlText : this.policyYaml;
      },
      set(v) {
        this.yamlText = v;
      },
    },
    policyYaml() {
      /* eslint-disable @gitlab/require-i18n-strings */
      const lines = [`name: '${this.policyName}'`, `description: '${this.policyDescription}'`];

      if (this.triggers.length) {
        lines.push('triggers:');
        this.triggers.forEach((t) => {
          lines.push(`  - type: ${t}`);
          this.serializeConfigInto(lines, this.triggerConfigs[t] || {}, '    ');
        });
      } else {
        lines.push('triggers: []');
      }

      if (this.rules.length) {
        lines.push('rules:');
        this.rules.forEach((r) => {
          lines.push(`  - type: ${r}`);
          this.serializeConfigInto(lines, this.ruleConfigs[r] || {}, '    ');
        });
      } else {
        lines.push('rules: []');
      }

      if (this.actions.length) {
        lines.push('actions:');
        this.actions.forEach((a) => {
          lines.push(`  - type: ${a}`);
          this.serializeConfigInto(lines, this.actionConfigs[a] || {}, '    ');
        });
      } else {
        lines.push('actions: []');
      }

      lines.push(`scope: ${this.policyData.scope || 'all'}`);
      /* eslint-enable @gitlab/require-i18n-strings */
      return lines.join('\n');
    },
  },
  watch: {
    yamlMode(entering) {
      if (!entering) this.yamlText = null;
    },
  },
  methods: {
    serializeConfigInto(lines, config, indent) {
      for (const [key, val] of Object.entries(config)) {
        if (val === '' || val === null || val === undefined) continue;
        if (Array.isArray(val)) {
          if (!val.length) continue;
          lines.push(`${indent}${key}:`);
          val.forEach((v) => lines.push(`${indent}  - ${v}`));
        } else if (val && typeof val === 'object') {
          const entries = Object.entries(val).filter(([, v]) => v !== '' && v != null);
          if (!entries.length) continue;
          lines.push(`${indent}${key}:`);
          entries.forEach(([k, v]) => lines.push(`${indent}  ${k}: ${v}`));
        } else if (typeof val === 'string' && val.includes('\n')) {
          lines.push(`${indent}${key}: |`);
          val
            .replace(/\n$/, '')
            .split('\n')
            .forEach((line) => lines.push(`${indent}  ${line}`));
        } else {
          lines.push(`${indent}${key}: ${val}`);
        }
      }
    },
    groupedFor(types) {
      const q = this.search.toLowerCase();
      const aiCategory = s__('SecurityOrchestration|AI');
      const nonAi = types.filter((item) => item.category !== aiCategory);
      const filtered = q
        ? nonAi.filter(
            (item) =>
              item.label.toLowerCase().includes(q) ||
              (item.description && item.description.toLowerCase().includes(q)),
          )
        : nonAi;
      const groups = {};
      const custom = [];
      for (const item of filtered) {
        if (!item.category) {
          custom.push(item);
        } else {
          if (!groups[item.category]) groups[item.category] = [];
          groups[item.category].push(item);
        }
      }
      /* eslint-disable @gitlab/require-i18n-strings */
      const CATEGORY_ORDER = [
        'AI',
        'CI/CD',
        'Code',
        'Security',
        'Compliance',
        'Access',
        'Integrations',
      ];
      /* eslint-enable @gitlab/require-i18n-strings */
      const sortedEntries = Object.entries(groups).sort(([a], [b]) => {
        const ai = CATEGORY_ORDER.indexOf(a);
        const bi = CATEGORY_ORDER.indexOf(b);
        if (ai === -1 && bi === -1) return a.localeCompare(b);
        if (ai === -1) return 1;
        if (bi === -1) return -1;
        return ai - bi;
      });
      const result = [];
      if (custom.length) result.push({ label: this.$options.i18n.custom, items: custom });
      for (const [label, items] of sortedEntries) {
        result.push({ label, items });
      }
      return result;
    },
    isTriggerAdded(id) {
      return this.triggers.includes(id);
    },
    isRuleAdded(id) {
      return this.rules.includes(id);
    },
    isActionAdded(id) {
      return this.actions.includes(id);
    },
    clickTrigger(id) {
      if (this.triggers.includes(id)) {
        this.triggers = this.triggers.filter((t) => t !== id);
      } else {
        this.triggers = [...this.triggers, id];
        this.expandedTriggers = { ...this.expandedTriggers, [id]: true };
      }
      this.emitUpdate();
    },
    removeTrigger(id) {
      this.triggers = this.triggers.filter((t) => t !== id);
      this.emitUpdate();
    },
    toggleTrigger(id) {
      this.expandedTriggers = { ...this.expandedTriggers, [id]: !this.expandedTriggers[id] };
    },
    triggerDef(id) {
      return TRIGGER_TYPES.find((t) => t.id === id);
    },
    clickRule(id) {
      if (this.rules.includes(id)) {
        this.rules = this.rules.filter((r) => r !== id);
      } else {
        this.rules = [...this.rules, id];
        this.expandedRules = { ...this.expandedRules, [id]: true };
      }
      this.emitUpdate();
    },
    clickAction(id) {
      if (this.actions.includes(id)) {
        this.actions = this.actions.filter((a) => a !== id);
      } else {
        this.actions = [...this.actions, id];
        this.expandedActions = { ...this.expandedActions, [id]: true };
      }
      this.emitUpdate();
    },
    removeRule(id) {
      this.rules = this.rules.filter((r) => r !== id);
      this.emitUpdate();
    },
    removeAction(id) {
      this.actions = this.actions.filter((a) => a !== id);
      this.emitUpdate();
    },
    toggleRule(id) {
      this.expandedRules = { ...this.expandedRules, [id]: !this.expandedRules[id] };
    },
    toggleAction(id) {
      this.expandedActions = { ...this.expandedActions, [id]: !this.expandedActions[id] };
    },
    updateTriggerConfig(id, value) {
      this.triggerConfigs = { ...this.triggerConfigs, [id]: value };
    },
    updateRuleConfig(id, value) {
      this.ruleConfigs = { ...this.ruleConfigs, [id]: value };
    },
    updateActionConfig(id, value) {
      this.actionConfigs = { ...this.actionConfigs, [id]: value };
    },
    configFor(map, id) {
      return map[id] || {};
    },
    ruleDef(id) {
      return RULE_TYPES.find((r) => r.id === id);
    },
    actionDef(id) {
      return ACTION_TYPES.find((a) => a.id === id);
    },
    emitUpdate() {
      this.$emit('update', {
        triggers: this.triggers,
        rules: this.rules,
        actions: this.actions,
        triggerConfigs: this.triggerConfigs,
        ruleConfigs: this.ruleConfigs,
        actionConfigs: this.actionConfigs,
      });
    },
    tabLabel(index) {
      const counts = [this.triggers.length, this.rules.length, this.actions.length];
      const labels = [
        this.$options.i18n.triggers,
        this.$options.i18n.rules,
        this.$options.i18n.actions,
      ];
      return counts[index] ? `${labels[index]} (${counts[index]})` : labels[index];
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-h-full">
    <!-- Left drawer: hidden in YAML mode -->
    <div
      v-if="!yamlMode"
      class="gl-border-r gl-flex gl-w-1/3 gl-flex-shrink-0 gl-flex-col gl-overflow-hidden gl-border-default gl-bg-subtle"
    >
      <!-- Underline tab nav -->
      <div class="gl-border-b gl-flex gl-flex-shrink-0 gl-border-default">
        <button
          v-for="i in [0, 1, 2]"
          :key="i"
          class="gl-cursor-pointer gl-border-0 gl-bg-transparent gl-px-6 gl-py-4"
          :class="
            activeTab === i
              ? 'gl-border-b-2 gl-border-blue-500 gl-font-bold gl-text-default'
              : 'gl-text-secondary hover:gl-text-default'
          "
          style="margin-bottom: -1px; font-size: 0.9375rem"
          @click="activeTab = i"
        >
          {{ tabLabel(i) }}
        </button>
      </div>

      <!-- Scrollable list area -->
      <div class="gl-flex-1 gl-overflow-y-auto gl-px-4 gl-pb-4 gl-pt-3">
        <!-- Triggers -->
        <template v-if="activeTab === 0">
          <div class="gl-mb-4 gl-flex gl-items-center gl-gap-2">
            <gl-search-box-by-type
              v-model="search"
              :placeholder="$options.i18n.searchPlaceholder"
              class="gl-flex-1"
            />
            <gl-button
              icon="filter"
              category="tertiary"
              size="small"
              :aria-label="s__('SecurityOrchestration|Filter')"
            />
          </div>
          <div v-for="group in triggersGrouped" :key="group.label" class="gl-mb-4">
            <p class="gl-mb-2 gl-mt-1 gl-px-1 gl-text-sm gl-font-bold gl-text-secondary">
              {{ group.label }}
            </p>
            <button
              v-for="item in group.items"
              :key="item.id"
              class="gl-border gl-mb-2 gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-gap-3 gl-rounded-base gl-border-default gl-bg-default gl-px-4 gl-py-3 gl-text-left hover:gl-border-blue-300"
              :class="isTriggerAdded(item.id) ? 'gl-border-blue-500 gl-bg-blue-50' : ''"
              @click="clickTrigger(item.id)"
              @mouseenter="hoveredItem = item.id"
              @mouseleave="hoveredItem = null"
            >
              <div
                class="gl-flex gl-h-5 gl-w-5 gl-flex-shrink-0 gl-items-center gl-justify-center gl-text-secondary"
              >
                <gl-icon :name="item.icon" :size="14" />
              </div>
              <span class="gl-min-w-0 gl-flex-1 gl-truncate" style="font-size: 0.9375rem">{{
                item.label
              }}</span>
              <gl-icon
                v-if="hoveredItem === item.id && item.description"
                v-gl-tooltip
                :title="item.description"
                name="information-o"
                :size="14"
                class="gl-flex-shrink-0 gl-text-secondary"
              />
              <gl-icon
                v-else-if="isTriggerAdded(item.id)"
                name="check-circle-filled"
                :size="14"
                class="gl-flex-shrink-0 gl-text-green-500"
              />
            </button>
          </div>
        </template>

        <!-- Rules -->
        <template v-if="activeTab === 1">
          <gl-search-box-by-type
            v-model="search"
            :placeholder="$options.i18n.searchPlaceholder"
            class="gl-mb-4"
          />
          <div v-for="group in rulesGrouped" :key="group.label" class="gl-mb-4">
            <p class="gl-mb-2 gl-mt-1 gl-px-1 gl-text-sm gl-font-bold gl-text-secondary">
              {{ group.label }}
            </p>
            <button
              v-for="item in group.items"
              :key="item.id"
              class="gl-border gl-mb-2 gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-gap-3 gl-rounded-base gl-border-default gl-bg-default gl-px-4 gl-py-3 gl-text-left hover:gl-border-blue-300"
              :class="isRuleAdded(item.id) ? 'gl-border-blue-500 gl-bg-blue-50' : ''"
              @click="clickRule(item.id)"
              @mouseenter="hoveredItem = item.id"
              @mouseleave="hoveredItem = null"
            >
              <div
                class="gl-flex gl-h-5 gl-w-5 gl-flex-shrink-0 gl-items-center gl-justify-center gl-text-secondary"
              >
                <gl-icon :name="item.icon" :size="14" />
              </div>
              <span class="gl-min-w-0 gl-flex-1 gl-truncate" style="font-size: 0.9375rem">{{
                item.label
              }}</span>
              <gl-icon
                v-if="hoveredItem === item.id && item.description"
                v-gl-tooltip
                :title="item.description"
                name="information-o"
                :size="14"
                class="gl-flex-shrink-0 gl-text-secondary"
              />
              <gl-icon
                v-else-if="isRuleAdded(item.id)"
                name="check-circle-filled"
                :size="14"
                class="gl-flex-shrink-0 gl-text-green-500"
              />
            </button>
          </div>
        </template>

        <!-- Actions -->
        <template v-if="activeTab === 2">
          <gl-search-box-by-type
            v-model="search"
            :placeholder="$options.i18n.searchPlaceholder"
            class="gl-mb-4"
          />
          <div v-for="group in actionsGrouped" :key="group.label" class="gl-mb-4">
            <p class="gl-mb-2 gl-mt-1 gl-px-1 gl-text-sm gl-font-bold gl-text-secondary">
              {{ group.label }}
            </p>
            <button
              v-for="item in group.items"
              :key="item.id"
              class="gl-border gl-mb-2 gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-gap-3 gl-rounded-base gl-border-default gl-bg-default gl-px-4 gl-py-3 gl-text-left hover:gl-border-blue-300"
              :class="isActionAdded(item.id) ? 'gl-border-blue-500 gl-bg-blue-50' : ''"
              @click="clickAction(item.id)"
              @mouseenter="hoveredItem = item.id"
              @mouseleave="hoveredItem = null"
            >
              <div
                class="gl-flex gl-h-5 gl-w-5 gl-flex-shrink-0 gl-items-center gl-justify-center gl-text-secondary"
              >
                <gl-icon :name="item.icon" :size="14" />
              </div>
              <span class="gl-min-w-0 gl-flex-1 gl-truncate" style="font-size: 0.9375rem">{{
                item.label
              }}</span>
              <gl-icon
                v-if="hoveredItem === item.id && item.description"
                v-gl-tooltip
                :title="item.description"
                name="information-o"
                :size="14"
                class="gl-flex-shrink-0 gl-text-secondary"
              />
              <gl-icon
                v-else-if="isActionAdded(item.id)"
                name="check-circle-filled"
                :size="14"
                class="gl-flex-shrink-0 gl-text-green-500"
              />
            </button>
          </div>
        </template>
      </div>

      <!-- Bundle library banner -->
      <div
        class="gl-border-t gl-mx-3 gl-mb-3 gl-flex gl-items-start gl-gap-3 gl-rounded-base gl-border-default gl-bg-subtle gl-p-3"
      >
        <div
          class="gl-flex gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-full"
          style="
            width: 32px;
            height: 32px;
            background: linear-gradient(135deg, #7b2fff 0%, #ff6b35 100%);
          "
        >
          <gl-icon name="tanuki" :size="14" class="gl-text-white" />
        </div>
        <div class="gl-min-w-0">
          <p class="gl-mb-1 gl-text-sm gl-text-secondary">{{ $options.i18n.bundleBanner }}</p>
          <gl-button category="tertiary" size="small" class="gl-px-0 gl-text-blue-500">
            {{ $options.i18n.browseBundleLibrary }}
          </gl-button>
        </div>
      </div>
    </div>

    <!-- Right panel -->
    <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-overflow-hidden">
      <!-- Visual / YAML segmented control -->
      <div class="gl-border-b gl-flex gl-flex-shrink-0 gl-border-default">
        <button
          class="gl-border-r gl-flex gl-flex-1 gl-cursor-pointer gl-items-center gl-justify-center gl-gap-2 gl-border-0 gl-border-default gl-py-4"
          :class="
            !yamlMode
              ? 'gl-bg-default gl-font-semibold gl-text-default'
              : 'gl-bg-subtle gl-text-secondary'
          "
          @click="yamlMode = false"
        >
          <gl-icon name="list-bulleted" :size="16" />
          <span style="font-size: 0.9375rem">{{ $options.i18n.visual }}</span>
        </button>
        <button
          class="gl-flex gl-flex-1 gl-cursor-pointer gl-items-center gl-justify-center gl-gap-2 gl-border-0 gl-py-4"
          :class="
            yamlMode
              ? 'gl-bg-default gl-font-semibold gl-text-default'
              : 'gl-bg-subtle gl-text-secondary'
          "
          @click="yamlMode = true"
        >
          <gl-icon name="doc-code" :size="16" />
          <span style="font-size: 0.9375rem">{{ $options.i18n.yaml }}</span>
        </button>
      </div>

      <!-- YAML view -->
      <div v-if="yamlMode" class="gl-flex gl-flex-1 gl-flex-col gl-overflow-hidden gl-p-5">
        <h3 class="gl-heading-5 gl-mb-1">{{ $options.i18n.yamlEditor }}</h3>
        <p class="gl-mb-4 gl-text-sm gl-text-secondary">{{ $options.i18n.yamlEditorDesc }}</p>
        <div
          class="gl-border gl-overflow-hidden gl-rounded-base gl-border-default"
          style="position: relative; min-height: 400px; flex: 1 1 400px"
        >
          <yaml-editor
            :value="yamlContent"
            :read-only="false"
            disable-schema
            style="position: absolute; top: 0; right: 0; bottom: 0; left: 0; height: 100%"
            @input="yamlContent = $event"
          />
        </div>
      </div>

      <!-- Visual view -->
      <div v-else class="gl-overflow-y-auto gl-p-5">
        <!-- AI/Duo banner -->
        <div
          v-if="showAiBanner"
          class="gl-mb-5 gl-flex gl-items-center gl-justify-between gl-rounded-base gl-px-4 gl-py-3"
          style="background: linear-gradient(135deg, #2d1b69 0%, #0d0b14 100%)"
        >
          <div class="gl-flex gl-items-center gl-gap-2">
            <gl-icon name="tanuki-ai" :size="16" class="gl-text-orange-400" />
            <span class="gl-text-sm gl-text-white">{{ $options.i18n.aiBanner }}</span>
          </div>
          <gl-button size="small" category="primary" class="gl-bg-white gl-text-gray-900">
            {{ $options.i18n.tryIt }}
          </gl-button>
        </div>

        <!-- Triggers section -->
        <div class="gl-mb-6">
          <h3 class="gl-mb-0.5 gl-heading-5">{{ $options.i18n.triggers }}</h3>
          <p class="gl-mb-3 gl-text-sm gl-text-secondary">{{ $options.i18n.triggersDesc }}</p>
          <template v-if="triggers.length">
            <template v-for="(triggerId, index) in triggers">
              <div
                v-if="index > 0"
                :key="`or-${triggerId}`"
                class="gl-my-2 gl-flex gl-justify-center"
              >
                <span
                  class="gl-rounded-full gl-px-3 gl-py-1 gl-text-xs gl-font-bold"
                  style="background: #fef3e2; color: #c96a00"
                  >{{ __('OR') }}</span
                >
              </div>
              <div :key="triggerId" class="gl-border gl-mb-2 gl-rounded-base gl-border-default">
                <div class="gl-flex gl-items-start gl-justify-between gl-px-3 gl-py-2">
                  <button
                    class="gl-flex gl-flex-1 gl-cursor-pointer gl-items-start gl-gap-2 gl-border-0 gl-bg-transparent gl-p-0 gl-text-left"
                    @click="toggleTrigger(triggerId)"
                  >
                    <gl-icon
                      :name="triggerDef(triggerId) && triggerDef(triggerId).icon"
                      :size="14"
                      class="gl-mt-0.5 gl-flex-shrink-0 gl-text-secondary"
                    />
                    <div>
                      <p class="gl-mb-0 gl-text-sm gl-font-bold">
                        {{ triggerDef(triggerId) && triggerDef(triggerId).label }}
                      </p>
                      <p
                        v-if="triggerDef(triggerId) && triggerDef(triggerId).description"
                        class="gl-mt-0.5 gl-mb-0 gl-text-xs gl-text-secondary"
                      >
                        {{ triggerDef(triggerId).description }}
                      </p>
                    </div>
                    <gl-icon
                      :name="expandedTriggers[triggerId] ? 'chevron-up' : 'chevron-down'"
                      :size="12"
                      class="gl-ml-auto gl-flex-shrink-0 gl-text-secondary"
                    />
                  </button>
                  <gl-button
                    icon="close"
                    size="small"
                    category="tertiary"
                    :aria-label="$options.i18n.remove"
                    @click="removeTrigger(triggerId)"
                  />
                </div>
                <div
                  v-if="
                    expandedTriggers[triggerId] &&
                    triggerDef(triggerId) &&
                    triggerDef(triggerId).fields &&
                    triggerDef(triggerId).fields.length
                  "
                  class="gl-border-t gl-border-default gl-p-3"
                >
                  <generic-config
                    :fields="triggerDef(triggerId).fields"
                    :value="configFor(triggerConfigs, triggerId)"
                    @input="updateTriggerConfig(triggerId, $event)"
                  />
                </div>
              </div>
            </template>
          </template>
          <button
            class="gl-gap-1.5 gl-border gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-justify-center gl-rounded-base gl-border-default gl-bg-transparent gl-py-2 gl-text-sm gl-text-secondary hover:gl-bg-subtle"
            @click="
              yamlMode = false;
              activeTab = 0;
            "
          >
            <gl-icon name="plus" :size="14" />
            {{ $options.i18n.addTrigger }}
          </button>
        </div>

        <!-- Rules section -->
        <div class="gl-mb-6">
          <h3 class="gl-mb-0.5 gl-heading-5">{{ $options.i18n.rules }}</h3>
          <p class="gl-mb-3 gl-text-sm gl-text-secondary">{{ $options.i18n.rulesDesc }}</p>
          <template v-if="rules.length">
            <template v-for="(ruleId, index) in rules">
              <div
                v-if="index > 0"
                :key="`and-${ruleId}`"
                class="gl-my-2 gl-flex gl-justify-center"
              >
                <span
                  class="gl-rounded-full gl-px-3 gl-py-1 gl-text-xs gl-font-bold"
                  style="background: #e9f3ff; color: #1f75cb"
                  >{{ __('AND') }}</span
                >
              </div>
              <div :key="ruleId" class="gl-border gl-mb-2 gl-rounded-base gl-border-default">
                <div class="gl-flex gl-items-start gl-justify-between gl-px-3 gl-py-2">
                  <button
                    class="gl-flex gl-flex-1 gl-cursor-pointer gl-items-start gl-gap-2 gl-border-0 gl-bg-transparent gl-p-0 gl-text-left"
                    @click="toggleRule(ruleId)"
                  >
                    <gl-icon
                      :name="ruleDef(ruleId) && ruleDef(ruleId).icon"
                      :size="14"
                      class="gl-mt-0.5 gl-flex-shrink-0 gl-text-secondary"
                    />
                    <div>
                      <p class="gl-mb-0 gl-text-sm gl-font-bold">
                        {{ ruleDef(ruleId) && ruleDef(ruleId).label }}
                      </p>
                      <p
                        v-if="ruleDef(ruleId) && ruleDef(ruleId).description"
                        class="gl-mt-0.5 gl-mb-0 gl-text-xs gl-text-secondary"
                      >
                        {{ ruleDef(ruleId).description }}
                      </p>
                    </div>
                    <gl-icon
                      :name="expandedRules[ruleId] ? 'chevron-up' : 'chevron-down'"
                      :size="12"
                      class="gl-ml-auto gl-flex-shrink-0 gl-text-secondary"
                    />
                  </button>
                  <gl-button
                    icon="close"
                    size="small"
                    category="tertiary"
                    :aria-label="$options.i18n.remove"
                    @click="removeRule(ruleId)"
                  />
                </div>
                <div
                  v-if="expandedRules[ruleId] && ruleDef(ruleId)"
                  class="gl-border-t gl-border-default gl-p-3"
                >
                  <generic-config
                    :fields="ruleDef(ruleId).fields"
                    :value="configFor(ruleConfigs, ruleId)"
                    @input="updateRuleConfig(ruleId, $event)"
                  />
                </div>
              </div>
            </template>
          </template>
          <button
            class="gl-gap-1.5 gl-border gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-justify-center gl-rounded-base gl-border-default gl-bg-transparent gl-py-2 gl-text-sm gl-text-secondary hover:gl-bg-subtle"
            @click="
              yamlMode = false;
              activeTab = 1;
            "
          >
            <gl-icon name="plus" :size="14" />
            {{ $options.i18n.addRule }}
          </button>
        </div>

        <!-- Actions section -->
        <div class="gl-mb-6">
          <h3 class="gl-mb-0.5 gl-heading-5">{{ $options.i18n.actions }}</h3>
          <p class="gl-mb-3 gl-text-sm gl-text-secondary">{{ $options.i18n.actionsDesc }}</p>
          <template v-if="actions.length">
            <template v-for="(actionId, index) in actions">
              <div
                v-if="index > 0"
                :key="`and-${actionId}`"
                class="gl-my-2 gl-flex gl-justify-center"
              >
                <span
                  class="gl-rounded-full gl-px-3 gl-py-1 gl-text-xs gl-font-bold"
                  style="background: #e9f3ff; color: #1f75cb"
                  >{{ __('AND') }}</span
                >
              </div>
              <div :key="actionId" class="gl-border gl-mb-2 gl-rounded-base gl-border-default">
                <div class="gl-flex gl-items-start gl-justify-between gl-px-3 gl-py-2">
                  <button
                    class="gl-flex gl-flex-1 gl-cursor-pointer gl-items-start gl-gap-2 gl-border-0 gl-bg-transparent gl-p-0 gl-text-left"
                    @click="toggleAction(actionId)"
                  >
                    <gl-icon
                      :name="actionDef(actionId) && actionDef(actionId).icon"
                      :size="14"
                      class="gl-mt-0.5 gl-flex-shrink-0 gl-text-secondary"
                    />
                    <div>
                      <p class="gl-mb-0 gl-text-sm gl-font-bold">
                        {{ actionDef(actionId) && actionDef(actionId).label }}
                      </p>
                      <p
                        v-if="actionDef(actionId) && actionDef(actionId).description"
                        class="gl-mt-0.5 gl-mb-0 gl-text-xs gl-text-secondary"
                      >
                        {{ actionDef(actionId).description }}
                      </p>
                    </div>
                    <gl-icon
                      :name="expandedActions[actionId] ? 'chevron-up' : 'chevron-down'"
                      :size="12"
                      class="gl-ml-auto gl-flex-shrink-0 gl-text-secondary"
                    />
                  </button>
                  <gl-button
                    icon="close"
                    size="small"
                    category="tertiary"
                    :aria-label="$options.i18n.remove"
                    @click="removeAction(actionId)"
                  />
                </div>
                <div
                  v-if="expandedActions[actionId] && actionDef(actionId)"
                  class="gl-border-t gl-border-default gl-p-3"
                >
                  <generic-config
                    :fields="actionDef(actionId).fields"
                    :value="configFor(actionConfigs, actionId)"
                    @input="updateActionConfig(actionId, $event)"
                  />
                </div>
              </div>
            </template>
          </template>
          <button
            class="gl-gap-1.5 gl-border gl-flex gl-w-full gl-cursor-pointer gl-items-center gl-justify-center gl-rounded-base gl-border-default gl-bg-transparent gl-py-2 gl-text-sm gl-text-secondary hover:gl-bg-subtle"
            @click="
              yamlMode = false;
              activeTab = 2;
            "
          >
            <gl-icon name="plus" :size="14" />
            {{ $options.i18n.addAction }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
